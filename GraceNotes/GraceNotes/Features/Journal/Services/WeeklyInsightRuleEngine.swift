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

        let narrativeSummary = candidateBuilder.narrativeSummary(from: selectedInsights)
        let resurfacingMessage = selectedInsights.first?.observation
            ?? String(localized: "review.insights.starterReflection")
        let continuityPrompt = selectedInsights.compactMap(\.action).first
            ?? candidateBuilder.defaultContinuityPrompt

        return WeeklyInsightAnalysis(
            weeklyInsights: selectedInsights,
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
}
