import Foundation

// Coherence repair helpers add length; keep logic in one type.
// swiftlint:disable file_length type_body_length function_body_length
struct CloudSanitizedRecurringThemeLists: Sendable {
    let gratitudes: [CloudReviewTheme]
    let needs: [CloudReviewTheme]
    let people: [CloudReviewTheme]
}

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

    /// High-precision substrings: generic personality / wellness gloss, not user theme text.
    private let interpretivePhrases = [
        "shows that you",
        "suggests you",
        "indicates you",
        "demonstrates that you",
        "you are the kind of person",
        "work-life balance",
        "work life balance",
        "cherish the little things",
        "value the small things",
        "显示出",
        "表明你在",
        "说明你在",
        "这意味着你",
        "珍惜日常小事",
        "工作生活平衡",
        "说明你重视",
        "看得出你很"
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

        let resurfacingMessage = sanitizeResurfacingMessage(
            payload.resurfacingMessage,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            fallback: fallbackResurfacing
        )
        var narrativeSummary = sanitizeNarrativeSummary(
            payload.narrativeSummary,
            allThemes: allThemes,
            fallback: fallbackNarrative
        )
        narrativeSummary = repairNarrativeWhenParrotsResurfacing(
            narrative: narrativeSummary,
            resurfacing: resurfacingMessage,
            allThemes: allThemes,
            fallback: fallbackNarrative
        )
        narrativeSummary = repairNarrativeWhenInterpretiveOrObservationWeak(
            narrative: narrativeSummary,
            resurfacing: resurfacingMessage,
            allThemes: allThemes,
            fallback: fallbackNarrative
        )

        var continuityPrompt = sanitizeContinuityPrompt(
            payload.continuityPrompt,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            fallback: fallbackContinuity
        )
        continuityPrompt = repairContinuityWhenChainWeak(
            continuity: continuityPrompt,
            narrative: narrativeSummary,
            resurfacing: resurfacingMessage,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            fallback: fallbackContinuity
        )

        return CloudReviewInsightsPayload(
            narrativeSummary: narrativeSummary,
            resurfacingMessage: resurfacingMessage,
            continuityPrompt: continuityPrompt,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople
        )
    }

    /// Sanitizes recurring theme lists and applies a light pass on locally rendered Review copy (length clamp,
    /// interpretive narrative repair, weak-chain continuity repair). Does not replace Observation with synthesized
    /// frequency lines the way ``sanitizePayload`` does for legacy one-shot model prose.
    func sanitizeStructuredPayload(_ payload: CloudReviewInsightsPayload) -> CloudReviewInsightsPayload {
        let fallbackNarrative = String(localized: "You kept a steady reflection rhythm this week.")
        let fallbackResurfacing = String(
            localized: "You are building momentum by returning to reflection this week."
        )
        let fallbackContinuity = String(localized: "What is one next step you can take tomorrow?")
        let recurringGratitudes = sanitizeThemes(payload.recurringGratitudes)
        let recurringNeeds = sanitizeThemes(payload.recurringNeeds)
        let recurringPeople = sanitizeThemes(payload.recurringPeople)
        let allThemes = recurringNeeds + recurringPeople + recurringGratitudes

        var narrativeSummary = sanitizeMessage(payload.narrativeSummary, fallback: fallbackNarrative)
        if seemsInterpretiveFiller(narrativeSummary) {
            narrativeSummary = synthesizedJuxtapositionNarrative(allThemes: allThemes, fallback: fallbackNarrative)
        }

        let resurfacingMessage = sanitizeMessage(payload.resurfacingMessage, fallback: fallbackResurfacing)
        var continuityPrompt = sanitizeMessage(payload.continuityPrompt, fallback: fallbackContinuity)
        continuityPrompt = repairContinuityWhenChainWeak(
            continuity: continuityPrompt,
            narrative: narrativeSummary,
            resurfacing: resurfacingMessage,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            fallback: fallbackContinuity
        )

        return CloudReviewInsightsPayload(
            narrativeSummary: narrativeSummary,
            resurfacingMessage: resurfacingMessage,
            continuityPrompt: continuityPrompt,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople
        )
    }

    func sanitizedRecurringLists(
        gratitudes: [CloudReviewTheme],
        needs: [CloudReviewTheme],
        people: [CloudReviewTheme]
    ) -> CloudSanitizedRecurringThemeLists {
        CloudSanitizedRecurringThemeLists(
            gratitudes: sanitizeThemes(gratitudes),
            needs: sanitizeThemes(needs),
            people: sanitizeThemes(people)
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
        let narrative = payload.narrativeSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !narrative.isEmpty, !seemsInterpretiveFiller(narrative) else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        guard narrativeGroundsObservation(
            narrative: narrative,
            resurfacing: payload.resurfacingMessage,
            allThemes: allThemes
        ) else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        guard continuityGroundsChain(
            continuity: payload.continuityPrompt,
            narrative: narrative,
            resurfacing: payload.resurfacingMessage,
            allThemes: allThemes
        ) else {
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

    /// When the model echoes the same line for Observation and Thinking, swap in distinct copy that still
    /// references themes.
    private func repairNarrativeWhenParrotsResurfacing(
        narrative: String,
        resurfacing: String,
        allThemes: [CloudReviewTheme],
        fallback: String
    ) -> String {
        guard narrativeParrotsResurfacing(narrative, resurfacing) else {
            return narrative
        }
        return synthesizedJuxtapositionNarrative(allThemes: allThemes, fallback: fallback)
    }

    private func repairNarrativeWhenInterpretiveOrObservationWeak(
        narrative: String,
        resurfacing: String,
        allThemes: [CloudReviewTheme],
        fallback: String
    ) -> String {
        let trimmed = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           !seemsInterpretiveFiller(trimmed),
           narrativeGroundsObservation(narrative: trimmed, resurfacing: resurfacing, allThemes: allThemes) {
            return sanitizeMessage(trimmed, fallback: fallback)
        }
        return synthesizedJuxtapositionNarrative(allThemes: allThemes, fallback: fallback)
    }

    private func synthesizedJuxtapositionNarrative(
        allThemes: [CloudReviewTheme],
        fallback: String
    ) -> String {
        guard !allThemes.isEmpty else {
            return sanitizeMessage(fallback, fallback: fallback)
        }
        if allThemes.count >= 2 {
            let line = String(
                format: String(localized: "%1$@ kept showing up alongside %2$@ in what you wrote this week."),
                allThemes[0].label,
                allThemes[1].label
            )
            return sanitizeMessage(line, fallback: fallback)
        }
        let line = String(
            format: String(localized: "Across several entries, %@ was a thread you returned to often."),
            allThemes[0].label
        )
        return sanitizeMessage(line, fallback: fallback)
    }

    // swiftlint:disable:next function_parameter_count
    private func repairContinuityWhenChainWeak(
        continuity: String,
        narrative: String,
        resurfacing: String,
        recurringGratitudes: [CloudReviewTheme],
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme],
        fallback: String
    ) -> String {
        let allThemes = recurringNeeds + recurringPeople + recurringGratitudes
        guard !allThemes.isEmpty else {
            return sanitizeMessage(continuity, fallback: fallback)
        }
        let trimmed = continuity.trimmingCharacters(in: .whitespacesAndNewlines)
        if continuityGroundsChain(
            continuity: trimmed,
            narrative: narrative,
            resurfacing: resurfacing,
            allThemes: allThemes
        ) {
            return sanitizeMessage(trimmed, fallback: fallback)
        }
        let union = chainThemeUnion(narrative: narrative, resurfacing: resurfacing, themes: allThemes)
        let pool = union.isEmpty ? allThemes : union
        let replacement = continuityReplacement(
            for: pool,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            recurringGratitudes: recurringGratitudes,
            fallback: fallback
        )
        return sanitizeMessage(replacement, fallback: fallback)
    }

    private func continuityReplacement(
        for pool: [CloudReviewTheme],
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme],
        recurringGratitudes: [CloudReviewTheme],
        fallback: String
    ) -> String {
        for theme in pool where recurringNeeds.contains(where: { labelsMatch($0.label, theme.label) }) {
            return String(
                format: String(localized: "What is one small step you can take to support %@ tomorrow?"),
                theme.label
            )
        }
        for theme in pool where recurringPeople.contains(where: { labelsMatch($0.label, theme.label) }) {
            return String(
                format: String(localized: "How could you connect with %@ in a meaningful way this week?"),
                theme.label
            )
        }
        if let theme = pool.first {
            return String(
                format: String(localized: "How can you carry %@ into tomorrow?"),
                theme.label
            )
        }
        return fallback
    }

    private func labelsMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizeForMatching(lhs) == normalizeForMatching(rhs)
    }

    private func themesReferencedInMessage(_ message: String, themes: [CloudReviewTheme]) -> [CloudReviewTheme] {
        let normalizedMessage = normalizeForMatching(message)
        return themes.filter { labelReferencedInMessage($0.label, normalizedMessage: normalizedMessage) }
    }

    private func chainThemeUnion(
        narrative: String,
        resurfacing: String,
        themes: [CloudReviewTheme]
    ) -> [CloudReviewTheme] {
        let fromResurfacing = themesReferencedInMessage(resurfacing, themes: themes)
        let fromNarrative = themesReferencedInMessage(narrative, themes: themes)
        var seen = Set<String>()
        var result: [CloudReviewTheme] = []
        for theme in fromResurfacing + fromNarrative {
            let key = normalizeForMatching(theme.label)
            guard !key.isEmpty else { continue }
            if seen.insert(key).inserted {
                result.append(theme)
            }
        }
        return result
    }

    private func narrativeGroundsObservation(
        narrative: String,
        resurfacing: String,
        allThemes: [CloudReviewTheme]
    ) -> Bool {
        let inResurfacing = themesReferencedInMessage(resurfacing, themes: allThemes)
        if inResurfacing.isEmpty {
            return mentionsAnyTheme(narrative, themes: allThemes)
        }
        return mentionsAnyTheme(narrative, themes: inResurfacing)
    }

    private func continuityGroundsChain(
        continuity: String,
        narrative: String,
        resurfacing: String,
        allThemes: [CloudReviewTheme]
    ) -> Bool {
        let union = chainThemeUnion(narrative: narrative, resurfacing: resurfacing, themes: allThemes)
        let pool = union.isEmpty ? allThemes : union
        return mentionsAnyTheme(continuity, themes: pool)
    }

    private func seemsInterpretiveFiller(_ message: String) -> Bool {
        let normalized = normalizeForMatching(message)
        return interpretivePhrases.contains { normalized.contains($0) }
    }

    private func narrativeParrotsResurfacing(_ narrative: String, _ resurfacing: String) -> Bool {
        let normalizedNarrative = normalizeForMatching(narrative)
        let normalizedResurfacing = normalizeForMatching(resurfacing)
        guard !normalizedNarrative.isEmpty, !normalizedResurfacing.isEmpty else { return false }
        if normalizedNarrative == normalizedResurfacing { return true }
        if normalizedNarrative.count >= 24, normalizedResurfacing.count >= 24,
           normalizedNarrative.contains(normalizedResurfacing) || normalizedResurfacing.contains(normalizedNarrative) {
            return true
        }
        return false
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
            labelReferencedInMessage(theme.label, normalizedMessage: normalizedMessage)
        }
    }

    /// Full-label substring match first; then token / adjacent-pair passes so short paraphrases still tie to themes.
    private func labelReferencedInMessage(_ label: String, normalizedMessage: String) -> Bool {
        let normalizedLabel = normalizeForMatching(label)
        guard !normalizedLabel.isEmpty else { return false }
        if normalizedMessage.contains(normalizedLabel) {
            return true
        }
        let tokens = normalizedLabel.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for token in tokens where token.count >= 3 {
            if normalizedMessage.contains(String(token)) {
                return true
            }
        }
        let chars = Array(normalizedLabel)
        guard chars.count >= 2 else {
            return false
        }
        for index in 0..<(chars.count - 1) {
            if chars[index].isASCII, chars[index + 1].isASCII {
                continue
            }
            let pair = String([chars[index], chars[index + 1]])
            if normalizedMessage.contains(pair) {
                return true
            }
        }
        return false
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
// swiftlint:enable file_length type_body_length function_body_length
