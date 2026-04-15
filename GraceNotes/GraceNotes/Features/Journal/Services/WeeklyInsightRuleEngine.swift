import Foundation

struct WeeklyInsightAnalysis {
    let weeklyInsights: [ReviewWeeklyInsight]
    let recurringGratitudes: [ReviewInsightTheme]
    let recurringNeeds: [ReviewInsightTheme]
    let recurringPeople: [ReviewInsightTheme]
    let narrativeSummary: String?
    let resurfacingMessage: String
    let continuityPrompt: String
    let weekStats: ReviewWeekStats
    let presentationMode: ReviewPresentationMode
}

struct WeeklyInsightRuleEngine {
    private let aggregatesBuilder = WeeklyReviewAggregatesBuilder()
    private let textNormalizer = WeeklyInsightTextNormalizer()

    // swiftlint:disable:next function_parameter_count
    func analyze(
        currentPeriod: Range<Date>,
        currentWeekEntries: [Journal],
        previousWeekEntries: [Journal],
        allEntries: [Journal],
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection = .default
    ) -> WeeklyInsightAnalysis {
        let candidateBuilder = WeeklyInsightCandidateBuilder(textNormalizer: textNormalizer)
        let aggregates = aggregatesBuilder.build(
            currentPeriod: currentPeriod,
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            allEntries: allEntries,
            calendar: calendar,
            referenceDate: referenceDate,
            pastStatisticsInterval: pastStatisticsInterval
        )

        let candidates = candidateBuilder.buildCandidates(inputs: aggregates.candidateInputs)

        let selectedInsights = candidateBuilder.selectInsights(
            from: candidates,
            fallback: candidateBuilder.fallbackInsight(
                reflectionDayCount: aggregates.candidateInputs.currentDayCount
            )
        )

        let normalizedInsights = Self.normalizedWeeklyInsights(selectedInsights)

        let narrativeSummary = candidateBuilder.narrativeSummary(from: normalizedInsights)
        let starterReflection = String(localized: "review.insights.starterReflection")
        let (headline, primaryInsight) = Self.headlineAndPrimaryInsight(from: normalizedInsights)
        let resurfacingMessage = headline ?? starterReflection

        let continuityPrompt = Self.continuityPrompt(
            matching: primaryInsight,
            in: normalizedInsights,
            defaultPrompt: candidateBuilder.defaultContinuityPrompt
        )

        return WeeklyInsightAnalysis(
            weeklyInsights: normalizedInsights,
            recurringGratitudes: aggregates.recurringGratitudes,
            recurringNeeds: aggregates.recurringNeeds,
            recurringPeople: aggregates.recurringPeople,
            narrativeSummary: narrativeSummary,
            resurfacingMessage: resurfacingMessage,
            continuityPrompt: continuityPrompt,
            weekStats: aggregates.stats,
            presentationMode: aggregates.supportsInsightNarrative ? .insight : .statsFirst
        )
    }

    /// Prefer a non-empty trimmed `action` from the same insight that drives the resurfacing headline
    /// (first insight with a non-empty observation or `primaryTheme`), then any other insight’s action,
    /// so the prompt stays aligned with the line the member actually sees.
    static func continuityPrompt(
        matching primaryInsight: ReviewWeeklyInsight?,
        in insights: [ReviewWeeklyInsight],
        defaultPrompt: String
    ) -> String {
        if let primary = primaryInsight,
           let action = primary.action,
           let trimmed = Self.nonEmptyTrimmed(action) {
            return trimmed
        }
        return insights
            .compactMap(\.action)
            .compactMap(Self.nonEmptyTrimmed)
            .first
            ?? defaultPrompt
    }

    static func nonEmptyTrimmed(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Scans all insights for a non-empty trimmed `observation` first, then any `primaryTheme`, so a later
    /// observation wins over an earlier blank observation + theme (used by headline tests).
    static func firstNonEmptyTrimmedHeadline(in insights: [ReviewWeeklyInsight]) -> String {
        for insight in insights {
            if let trimmed = Self.nonEmptyTrimmed(insight.observation) {
                return trimmed
            }
        }
        for insight in insights {
            if let theme = insight.primaryTheme.flatMap(Self.nonEmptyTrimmed) {
                return theme
            }
        }
        return ""
    }

    /// Prefer the first non-empty trimmed `observation` across selected insights. If an observation is blank
    /// but `primaryTheme` is present (e.g. failed template substitution), use the trimmed theme so the
    /// resurfacing line still matches visible card context instead of the generic starter copy.
    static func headlineAndPrimaryInsight(
        from insights: [ReviewWeeklyInsight]
    ) -> (headline: String?, primaryInsight: ReviewWeeklyInsight?) {
        for insight in insights {
            if let trimmedObservation = Self.nonEmptyTrimmed(insight.observation) {
                return (trimmedObservation, insight)
            }
            if let theme = insight.primaryTheme.flatMap(Self.nonEmptyTrimmed) {
                return (theme, insight)
            }
        }
        return (nil, nil)
    }
}

extension WeeklyInsightRuleEngine {
    /// Trims insight copy so `weeklyInsights` matches `resurfacingMessage` / `continuityPrompt`.
    static func normalizedWeeklyInsights(_ insights: [ReviewWeeklyInsight]) -> [ReviewWeeklyInsight] {
        insights.map { insight in
            let trimmedObservation = insight.observation.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAction = insight.action?.trimmingCharacters(in: .whitespacesAndNewlines)
            let action: String? = {
                guard let trimmedAction, !trimmedAction.isEmpty else { return nil }
                return trimmedAction
            }()
            return ReviewWeeklyInsight(
                pattern: insight.pattern,
                observation: trimmedObservation,
                action: action,
                primaryTheme: insight.primaryTheme,
                mentionCount: insight.mentionCount,
                dayCount: insight.dayCount
            )
        }
    }

    static func resurfacingMessage(
        for insights: [ReviewWeeklyInsight],
        emptyObservationFallback: String
    ) -> String {
        guard let headline = insights.first?.observation, !headline.isEmpty else {
            return emptyObservationFallback
        }
        return headline
    }

    static func continuityPrompt(
        for insights: [ReviewWeeklyInsight],
        defaultPrompt: String
    ) -> String {
        insights.compactMap(\.action).first ?? defaultPrompt
    }
}
