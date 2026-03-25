import Foundation

extension CloudReviewInsightsSanitizer {
    /// When the model echoes the same line for Observation and Thinking, swap in distinct copy that still
    /// references themes.
    func repairNarrativeWhenParrotsResurfacing(
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

    func repairNarrativeWhenInterpretiveOrObservationWeak(
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

    func synthesizedJuxtapositionNarrative(
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

    func repairContinuityWhenChainWeak(_ input: CloudReviewContinuityRepairInput) -> String {
        let allThemes = input.recurringNeeds + input.recurringPeople + input.recurringGratitudes
        guard !allThemes.isEmpty else {
            return sanitizeMessage(input.continuity, fallback: input.fallback)
        }
        let trimmed = input.continuity.trimmingCharacters(in: .whitespacesAndNewlines)
        if continuityGroundsChain(
            continuity: trimmed,
            narrative: input.narrative,
            resurfacing: input.resurfacing,
            allThemes: allThemes
        ) {
            return sanitizeMessage(trimmed, fallback: input.fallback)
        }
        let union = chainThemeUnion(
            narrative: input.narrative,
            resurfacing: input.resurfacing,
            themes: allThemes
        )
        let pool = union.isEmpty ? allThemes : union
        let replacement = continuityReplacement(
            for: pool,
            recurringNeeds: input.recurringNeeds,
            recurringPeople: input.recurringPeople,
            recurringGratitudes: input.recurringGratitudes,
            fallback: input.fallback
        )
        return sanitizeMessage(replacement, fallback: input.fallback)
    }

    func continuityReplacement(
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

    func labelsMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizeForMatching(lhs) == normalizeForMatching(rhs)
    }

    func themesReferencedInMessage(_ message: String, themes: [CloudReviewTheme]) -> [CloudReviewTheme] {
        let normalizedMessage = normalizeForMatching(message)
        return themes.filter { labelReferencedInMessage($0.label, normalizedMessage: normalizedMessage) }
    }

    func chainThemeUnion(
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

    func narrativeGroundsObservation(
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

    func continuityGroundsChain(
        continuity: String,
        narrative: String,
        resurfacing: String,
        allThemes: [CloudReviewTheme]
    ) -> Bool {
        let union = chainThemeUnion(narrative: narrative, resurfacing: resurfacing, themes: allThemes)
        let pool = union.isEmpty ? allThemes : union
        return mentionsAnyTheme(continuity, themes: pool)
    }

    func seemsInterpretiveFiller(_ message: String) -> Bool {
        let normalized = normalizeForMatching(message)
        return interpretivePhrases.contains { normalized.contains($0) }
    }

    func narrativeParrotsResurfacing(_ narrative: String, _ resurfacing: String) -> Bool {
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

    func sanitizeMessage(_ message: String, fallback: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? fallback : trimmed
        return String(source.prefix(maxMessageLength))
    }

    func sanitizeThemes(_ themes: [CloudReviewTheme]) -> [CloudReviewTheme] {
        themes
            .compactMap(sanitizeTheme)
            .prefix(maxThemesPerList)
            .map { $0 }
    }

    func sanitizeTheme(_ theme: CloudReviewTheme) -> CloudReviewTheme? {
        let trimmedLabel = theme.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return nil }
        guard theme.count > 0 else { return nil }
        return CloudReviewTheme(label: String(trimmedLabel.prefix(maxMessageLength)), count: theme.count)
    }

    func sanitizeNarrativeSummary(
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

    func sanitizeResurfacingMessage(
        _ message: String,
        recurringGratitudes: [CloudReviewTheme],
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme],
        fallback: String
    ) -> String {
        if let result = sanitizeResurfacingFromHighCountNeed(
            message: message,
            recurringNeeds: recurringNeeds,
            fallback: fallback
        ) {
            return result
        }
        if let result = sanitizeResurfacingFromHighCountPerson(
            message: message,
            recurringPeople: recurringPeople,
            fallback: fallback
        ) {
            return result
        }
        if let result = sanitizeResurfacingFromHighCountGratitude(
            message: message,
            recurringGratitudes: recurringGratitudes,
            fallback: fallback
        ) {
            return result
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

    private func sanitizeResurfacingFromHighCountNeed(
        message: String,
        recurringNeeds: [CloudReviewTheme],
        fallback: String
    ) -> String? {
        guard let topNeed = recurringNeeds.first, topNeed.count > 1 else { return nil }
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

    private func sanitizeResurfacingFromHighCountPerson(
        message: String,
        recurringPeople: [CloudReviewTheme],
        fallback: String
    ) -> String? {
        guard let topPerson = recurringPeople.first, topPerson.count > 1 else { return nil }
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

    private func sanitizeResurfacingFromHighCountGratitude(
        message: String,
        recurringGratitudes: [CloudReviewTheme],
        fallback: String
    ) -> String? {
        guard let topGratitude = recurringGratitudes.first, topGratitude.count > 1 else { return nil }
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

    func sanitizeContinuityPrompt(
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
    func groundedResurfacingLine(
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

    func mentionsAnyTheme(_ message: String, themes: [CloudReviewTheme]) -> Bool {
        let normalizedMessage = normalizeForMatching(message)
        return themes.contains { theme in
            labelReferencedInMessage(theme.label, normalizedMessage: normalizedMessage)
        }
    }

    /// Full-label substring match first; then token / adjacent-pair passes so short paraphrases still tie to themes.
    func labelReferencedInMessage(_ label: String, normalizedMessage: String) -> Bool {
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

    func seemsGeneric(_ message: String) -> Bool {
        let normalizedMessage = normalizeForMatching(message)
        return genericPhrases.contains { normalizedMessage.contains($0) }
    }

    func normalizeForMatching(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
