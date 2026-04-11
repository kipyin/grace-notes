import Foundation

/// Decides whether the Past tab narrative row should show a Next step line, and which text to use.
/// Hides generic duplicate lines (e.g. glad-happened substitution) and **short** recurring-theme echoes
/// when the same theme/person is already prominent in the stats blocks above.
struct ReviewNextStepRowRefiner {
    private let textNormalizer: WeeklyInsightTextNormalizer

    /// When the theme matches a top recurring row, actions shorter than this are treated as redundant.
    private let maxThinActionChars = 110

    init(textNormalizer: WeeklyInsightTextNormalizer = WeeklyInsightTextNormalizer()) {
        self.textNormalizer = textNormalizer
    }

    /// Returns `nil` when the row should not appear (no redundant or generic filler).
    /// Aligns with ``ReviewPresentationMode``: `.statsFirst` weeks stay rhythm-led and omit this narrative row.
    func nextStepText(for insights: ReviewInsights) -> String? {
        if insights.presentationMode == .statsFirst {
            return nil
        }

        let action = actionBodyCandidate(for: insights)
        let trimmed = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let gladHappened = String(localized: "review.prompts.gladHappened")
        if normalizedInsightText(trimmed) == normalizedInsightText(gladHappened) {
            return nil
        }

        if shouldHideThinRecurringEcho(insights, actionLine: trimmed) {
            return nil
        }

        return trimmed
    }

    private func actionBodyCandidate(for insights: ReviewInsights) -> String {
        let continuity = insights.continuityPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !continuity.isEmpty {
            return continuity
        }
        return insights.weeklyInsights
            .lazy
            .compactMap(\.action)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    /// When the insight is recurring-theme/people and the same label is already in the top
    /// ``ReviewWeekStats/mostRecurringThemes`` rows (what the Past cards above show), short template
    /// actions add little beyond those cards; longer behavioral lines are kept.
    private func shouldHideThinRecurringEcho(_ insights: ReviewInsights, actionLine: String) -> Bool {
        guard let first = insights.weeklyInsights.first,
              let primary = first.primaryTheme,
              !primary.isEmpty
        else {
            return false
        }

        switch first.pattern {
        case .recurringTheme, .recurringPeople:
            break
        case .needsGratitudeGap, .continuityShift, .fullCompletion, .sparseFallback:
            return false
        }

        let normalizedPrimary = textNormalizer.normalizeThemeLabel(primary)
        guard !normalizedPrimary.isEmpty else { return false }

        guard matchesTopRecurringLabels(normalizedPrimary, insights: insights) else {
            return false
        }

        guard actionLine.count < maxThinActionChars else {
            return false
        }

        return true
    }

    private func matchesTopRecurringLabels(_ normalizedPrimary: String, insights: ReviewInsights) -> Bool {
        for row in insights.weekStats.mostRecurringThemes.prefix(3)
            where textNormalizer.normalizeThemeLabel(row.label) == normalizedPrimary {
            return true
        }
        return false
    }

    private func normalizedInsightText(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
