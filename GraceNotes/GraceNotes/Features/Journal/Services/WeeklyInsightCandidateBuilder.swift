import Foundation

struct WeeklyInsightCandidateBuilder {
    let defaultContinuityPrompt = String(
        localized: "review.prompts.carryIntoNextWeek"
    )

    private let maxInsights = 2
    let textNormalizer: WeeklyInsightTextNormalizer

    init(textNormalizer: WeeklyInsightTextNormalizer) {
        self.textNormalizer = textNormalizer
    }

    func buildCandidates(inputs: CandidateInputs) -> [InsightCandidate] {
        if isSparseWeek(entries: inputs.entries, reflectionDayCount: inputs.currentDayCount) {
            return []
        }

        var candidates: [InsightCandidate] = []

        if let fullCompletion = fullCompletionCandidate(
            entries: inputs.entries,
            calendar: inputs.calendar
        ) {
            candidates.append(fullCompletion)
        }
        if let recurringPeople = recurringPeopleCandidate(from: inputs.people) {
            candidates.append(recurringPeople)
        }
        if let recurringTheme = recurringThemeCandidate(needs: inputs.needs, gratitudes: inputs.gratitudes) {
            candidates.append(recurringTheme)
        }
        if let gap = needsGratitudeGapCandidate(needs: inputs.needs, gratitudes: inputs.gratitudes) {
            candidates.append(gap)
        }
        if let shift = continuityShiftCandidate(
            currentThemes: inputs.currentContinuity,
            previousThemes: inputs.previousContinuity
        ) {
            candidates.append(shift)
        }

        return candidates
    }

    func selectInsights(
        from candidates: [InsightCandidate],
        fallback: ReviewWeeklyInsight
    ) -> [ReviewWeeklyInsight] {
        let sorted = candidates.sorted(by: compareCandidates)
        var selected: [ReviewWeeklyInsight] = []

        for candidate in sorted {
            guard selected.count < maxInsights else { break }
            if shouldSkip(candidate.insight, becauseOf: selected) {
                continue
            }
            selected.append(candidate.insight)
        }

        if selected.isEmpty {
            return [fallback]
        }

        return selected
    }

    func fallbackInsight(
        reflectionDayCount: Int
    ) -> ReviewWeeklyInsight {
        if reflectionDayCount == 0 {
            return ReviewWeeklyInsight(
                pattern: .sparseFallback,
                observation: String(
                    localized: "review.insights.starterReflection"
                ),
                action: defaultContinuityPrompt,
                primaryTheme: nil,
                mentionCount: nil,
                dayCount: 0
            )
        }

        return ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: renderLocalizedDayCountTemplate(
                "review.insights.reflectionDays.observation",
                dayCount: reflectionDayCount
            ),
            action: String(localized: "review.prompts.easyCheckInTomorrow"),
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: reflectionDayCount
        )
    }

    func narrativeSummary(from insights: [ReviewWeeklyInsight]) -> String? {
        guard !insights.isEmpty else { return nil }
        if insights.count >= 2 {
            let first = insights[0].observation
            let second = insights[1].observation
            if !observationsAreEffectivelyDuplicate(first, second) {
                return second
            }
            let themeA = insights[0].primaryTheme
            let themeB = insights[1].primaryTheme
            if let firstTheme = themeA, let secondTheme = themeB,
               !firstTheme.isEmpty, !secondTheme.isEmpty,
               !textNormalizer.themesMatch(
                   textNormalizer.normalizeThemeLabel(firstTheme),
                   against: [textNormalizer.normalizeThemeLabel(secondTheme)]
               ) {
                return String(
                    format: String(localized: "review.insights.bothThemesMultiple"),
                    firstTheme,
                    secondTheme
                )
            }
            return second
        }
        if let theme = insights[0].primaryTheme, !theme.isEmpty {
            return String(
                format: String(localized: "review.insights.threadAcrossDays"),
                theme
            )
        }
        let first = insights[0]
        if first.pattern == .sparseFallback, first.dayCount == 0 {
            return nil
        }
        let observation = first.observation.trimmingCharacters(in: .whitespacesAndNewlines)
        return observation.isEmpty ? nil : observation
    }

    private func observationsAreEffectivelyDuplicate(_ lhs: String, _ rhs: String) -> Bool {
        normalizeObservationLine(lhs) == normalizeObservationLine(rhs)
    }

    private func normalizeObservationLine(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct InsightCandidate {
    let score: Int
    let insight: ReviewWeeklyInsight
}
