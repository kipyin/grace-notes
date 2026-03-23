import Foundation

struct CloudReviewInsightsSanitizer {
    private let maxThemesPerList = 3
    private let maxMessageLength = 160
    private let genericPhrases = [
        "take it one day at a time",
        "be kind to yourself",
        "you are doing great",
        "keep going",
        "stay positive",
        "small steps",
        "一步一步来",
        "善待自己",
        "你做得很好",
        "继续加油",
        "保持积极",
        "小步骤"
    ]

    func sanitizePayload(_ payload: CloudReviewInsightsPayload) -> CloudReviewInsightsPayload {
        let fallbackNarrative = String(localized: "You kept a steady reflection rhythm this week.")
        let fallbackResurfacing = String(
            localized: "You are building momentum by returning to reflection this week."
        )
        let fallbackContinuity = String(localized: "What is one next step you can take tomorrow?")
        let recurringGratitudes = sanitizeThemes(payload.recurringGratitudes)
        let recurringNeeds = sanitizeThemes(payload.recurringNeeds)
        let recurringPeople = sanitizeThemes(payload.recurringPeople)
        let allThemes = recurringNeeds + recurringPeople + recurringGratitudes

        return CloudReviewInsightsPayload(
            narrativeSummary: sanitizeNarrativeSummary(
                payload.narrativeSummary,
                allThemes: allThemes,
                fallback: fallbackNarrative
            ),
            resurfacingMessage: sanitizeResurfacingMessage(
                payload.resurfacingMessage,
                recurringGratitudes: recurringGratitudes,
                recurringNeeds: recurringNeeds,
                recurringPeople: recurringPeople,
                fallback: fallbackResurfacing
            ),
            continuityPrompt: sanitizeContinuityPrompt(
                payload.continuityPrompt,
                recurringGratitudes: recurringGratitudes,
                recurringNeeds: recurringNeeds,
                recurringPeople: recurringPeople,
                fallback: fallbackContinuity
            ),
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople
        )
    }

    /// Hard gate after sanitization: reject payloads that are still too generic or not tied to recurring signals.
    func validateGroundedQuality(_ payload: CloudReviewInsightsPayload) throws {
        let allThemes = payload.recurringNeeds + payload.recurringPeople + payload.recurringGratitudes
        guard !allThemes.isEmpty else {
            throw CloudReviewInsightsError.failedQualityGate
        }

        guard mentionsAnyTheme(payload.narrativeSummary, themes: allThemes) else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        guard mentionsAnyTheme(payload.resurfacingMessage, themes: allThemes) else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        guard mentionsAnyTheme(payload.continuityPrompt, themes: allThemes) else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        guard !seemsGeneric(payload.continuityPrompt) else {
            throw CloudReviewInsightsError.failedQualityGate
        }
    }

    func extractJSONPayload(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        if let fenceRange = trimmed.range(of: "```json"),
           let closeFenceRange = trimmed.range(of: "```", range: fenceRange.upperBound..<trimmed.endIndex) {
            let fenced = trimmed[fenceRange.upperBound..<closeFenceRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if fenced.hasPrefix("{"), fenced.hasSuffix("}") {
                return fenced
            }
        }

        guard let startIndex = trimmed.firstIndex(of: "{"),
              let endIndex = trimmed.lastIndex(of: "}")
        else {
            return content
        }
        return String(trimmed[startIndex...endIndex])
    }

    private func sanitizeMessage(_ message: String, fallback: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? fallback : trimmed
        return String(source.prefix(maxMessageLength))
    }

    private func sanitizeThemes(_ themes: [CloudReviewTheme]) -> [CloudReviewTheme] {
        themes
            .compactMap(sanitizeTheme)
            .prefix(maxThemesPerList)
            .map { $0 }
    }

    private func sanitizeTheme(_ theme: CloudReviewTheme) -> CloudReviewTheme? {
        let trimmedLabel = theme.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return nil }
        guard theme.count > 0 else { return nil }
        return CloudReviewTheme(label: String(trimmedLabel.prefix(maxMessageLength)), count: theme.count)
    }

    private func sanitizeNarrativeSummary(
        _ summary: String,
        allThemes: [CloudReviewTheme],
        fallback: String
    ) -> String {
        let message = sanitizeMessage(summary, fallback: fallback)
        guard !allThemes.isEmpty else { return message }
        guard mentionsAnyTheme(message, themes: allThemes) else {
            let previewThemes = allThemes.prefix(2).map(\.label)
            let joined = ListFormatter.localizedString(byJoining: previewThemes)
            let replacement = String(
                format: String(localized: "This week your reflection often returned to %@."),
                joined
            )
            return sanitizeMessage(replacement, fallback: fallback)
        }
        return message
    }

    private func sanitizeResurfacingMessage(
        _ message: String,
        recurringGratitudes: [CloudReviewTheme],
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme],
        fallback: String
    ) -> String {
        if let topNeed = recurringNeeds.first, topNeed.count > 1 {
            let replacement = String(
                format: String(localized: "You mentioned %1$@ %2$lld times this week."),
                topNeed.label,
                topNeed.count
            )
            let candidate = sanitizeMessage(message, fallback: replacement)
            guard mentionsAnyTheme(candidate, themes: [topNeed]), !seemsGeneric(candidate) else {
                return sanitizeMessage(replacement, fallback: fallback)
            }
            return candidate
        }

        if let topPerson = recurringPeople.first, topPerson.count > 1 {
            let replacement = String(
                format: String(localized: "You kept %1$@ in mind %2$lld times this week."),
                topPerson.label,
                topPerson.count
            )
            let candidate = sanitizeMessage(message, fallback: replacement)
            guard mentionsAnyTheme(candidate, themes: [topPerson]), !seemsGeneric(candidate) else {
                return sanitizeMessage(replacement, fallback: fallback)
            }
            return candidate
        }

        if let topGratitude = recurringGratitudes.first, topGratitude.count > 1 {
            let replacement = String(
                format: String(localized: "You returned to %1$@ %2$lld times this week."),
                topGratitude.label,
                topGratitude.count
            )
            let candidate = sanitizeMessage(message, fallback: replacement)
            guard mentionsAnyTheme(candidate, themes: [topGratitude]), !seemsGeneric(candidate) else {
                return sanitizeMessage(replacement, fallback: fallback)
            }
            return candidate
        }

        let allThemes = recurringNeeds + recurringPeople + recurringGratitudes
        let candidate = sanitizeMessage(message, fallback: fallback)
        guard !allThemes.isEmpty else {
            return candidate
        }
        if mentionsAnyTheme(candidate, themes: allThemes), !seemsGeneric(candidate) {
            return candidate
        }
        let replacement = groundedResurfacingLine(
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            recurringGratitudes: recurringGratitudes,
            fallback: fallback
        )
        return sanitizeMessage(replacement, fallback: fallback)
    }

    private func sanitizeContinuityPrompt(
        _ prompt: String,
        recurringGratitudes: [CloudReviewTheme],
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme],
        fallback: String
    ) -> String {
        let message = sanitizeMessage(prompt, fallback: fallback)
        let allThemes = recurringNeeds + recurringPeople + recurringGratitudes
        guard !allThemes.isEmpty else {
            return message
        }

        if seemsGeneric(message) || !mentionsAnyTheme(message, themes: allThemes) {
            if let topNeed = recurringNeeds.first {
                let replacement = String(
                    format: String(localized: "What is one small step you can take to support %@ tomorrow?"),
                    topNeed.label
                )
                return sanitizeMessage(replacement, fallback: fallback)
            }

            if let topPerson = recurringPeople.first {
                let replacement = String(
                    format: String(localized: "How could you connect with %@ in a meaningful way this week?"),
                    topPerson.label
                )
                return sanitizeMessage(replacement, fallback: fallback)
            }

            if let topGratitude = recurringGratitudes.first {
                let replacement = String(
                    format: String(localized: "How can you carry %@ into tomorrow?"),
                    topGratitude.label
                )
                return sanitizeMessage(replacement, fallback: fallback)
            }
        }

        return message
    }

    /// When recurring counts are all 1, the model may omit theme tokens; synthesize a grounded resurfacing line.
    private func groundedResurfacingLine(
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme],
        recurringGratitudes: [CloudReviewTheme],
        fallback: String
    ) -> String {
        if let topNeed = recurringNeeds.first {
            if topNeed.count > 1 {
                return String(
                    format: String(localized: "You mentioned %1$@ %2$lld times this week."),
                    topNeed.label,
                    topNeed.count
                )
            }
            return String(
                format: String(localized: "You noted %@ across this week's entries."),
                topNeed.label
            )
        }
        if let topPerson = recurringPeople.first {
            if topPerson.count > 1 {
                return String(
                    format: String(localized: "You kept %1$@ in mind %2$lld times this week."),
                    topPerson.label,
                    topPerson.count
                )
            }
            return String(
                format: String(localized: "You noted %@ across this week's entries."),
                topPerson.label
            )
        }
        if let topGratitude = recurringGratitudes.first {
            if topGratitude.count > 1 {
                return String(
                    format: String(localized: "You returned to %1$@ %2$lld times this week."),
                    topGratitude.label,
                    topGratitude.count
                )
            }
            return String(
                format: String(localized: "You noted %@ across this week's entries."),
                topGratitude.label
            )
        }
        return fallback
    }

    private func mentionsAnyTheme(_ message: String, themes: [CloudReviewTheme]) -> Bool {
        let normalizedMessage = normalizeForMatching(message)
        return themes.contains { theme in
            let normalizedLabel = normalizeForMatching(theme.label)
            guard !normalizedLabel.isEmpty else { return false }
            return normalizedMessage.contains(normalizedLabel)
        }
    }

    private func seemsGeneric(_ message: String) -> Bool {
        let normalizedMessage = normalizeForMatching(message)
        return genericPhrases.contains { normalizedMessage.contains($0) }
    }

    private func normalizeForMatching(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
