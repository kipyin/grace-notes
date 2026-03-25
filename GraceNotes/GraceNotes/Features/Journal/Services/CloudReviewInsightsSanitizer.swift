import Foundation

struct CloudSanitizedRecurringThemeLists: Sendable {
    let gratitudes: [CloudReviewTheme]
    let needs: [CloudReviewTheme]
    let people: [CloudReviewTheme]
}

/// Bundles inputs for continuity-chain repair so the sanitizer stays within parameter-count limits.
struct CloudReviewContinuityRepairInput: Sendable {
    let continuity: String
    let narrative: String
    let resurfacing: String
    let recurringGratitudes: [CloudReviewTheme]
    let recurringNeeds: [CloudReviewTheme]
    let recurringPeople: [CloudReviewTheme]
    let fallback: String
}

struct CloudReviewInsightsSanitizer {
    let maxThemesPerList = 3
    let maxMessageLength = 160
    let genericPhrases = [
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
    let interpretivePhrases = [
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
        let narrativeSummary = narrativeSummaryAfterPayloadSanitize(
            rawSummary: payload.narrativeSummary,
            allThemes: allThemes,
            resurfacingMessage: resurfacingMessage,
            fallbackNarrative: fallbackNarrative
        )

        var continuityPrompt = sanitizeContinuityPrompt(
            payload.continuityPrompt,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            fallback: fallbackContinuity
        )
        continuityPrompt = repairContinuityWhenChainWeak(
            CloudReviewContinuityRepairInput(
                continuity: continuityPrompt,
                narrative: narrativeSummary,
                resurfacing: resurfacingMessage,
                recurringGratitudes: recurringGratitudes,
                recurringNeeds: recurringNeeds,
                recurringPeople: recurringPeople,
                fallback: fallbackContinuity
            )
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

    private func narrativeSummaryAfterPayloadSanitize(
        rawSummary: String,
        allThemes: [CloudReviewTheme],
        resurfacingMessage: String,
        fallbackNarrative: String
    ) -> String {
        var narrativeSummary = sanitizeNarrativeSummary(
            rawSummary,
            allThemes: allThemes,
            fallback: fallbackNarrative
        )
        narrativeSummary = repairNarrativeWhenParrotsResurfacing(
            narrative: narrativeSummary,
            resurfacing: resurfacingMessage,
            allThemes: allThemes,
            fallback: fallbackNarrative
        )
        return repairNarrativeWhenInterpretiveOrObservationWeak(
            narrative: narrativeSummary,
            resurfacing: resurfacingMessage,
            allThemes: allThemes,
            fallback: fallbackNarrative
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
            CloudReviewContinuityRepairInput(
                continuity: continuityPrompt,
                narrative: narrativeSummary,
                resurfacing: resurfacingMessage,
                recurringGratitudes: recurringGratitudes,
                recurringNeeds: recurringNeeds,
                recurringPeople: recurringPeople,
                fallback: fallbackContinuity
            )
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
}
