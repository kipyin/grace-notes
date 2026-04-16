import Foundation

struct DeterministicReviewInsightsGenerator: ReviewInsightsGenerating {
    private let ruleEngine = WeeklyInsightRuleEngine()

    func generateInsights(
        from entries: [Journal],
        referenceDate: Date,
        calendar: Calendar = .current,
        pastStatisticsInterval: PastStatisticsIntervalSelection = .default
    ) async throws -> ReviewInsights {
        let currentPeriod = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previousPeriod = ReviewInsightsPeriod.previousPeriod(before: currentPeriod, calendar: calendar)

        var currentWeekEntries: [Journal] = []
        var previousWeekEntries: [Journal] = []
        for entry in entries {
            let date = entry.entryDate
            if currentPeriod.contains(date) {
                currentWeekEntries.append(entry)
            } else if previousPeriod.contains(date) {
                previousWeekEntries.append(entry)
            }
        }

        let analysis = ruleEngine.analyze(
            currentPeriod: currentPeriod,
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate,
            pastStatisticsInterval: pastStatisticsInterval
        )

        return ReviewInsights(
            source: .deterministic,
            presentationMode: analysis.presentationMode,
            generatedAt: referenceDate,
            weekStart: currentPeriod.lowerBound,
            weekEnd: currentPeriod.upperBound,
            weeklyInsights: analysis.weeklyInsights,
            recurringGratitudes: analysis.recurringGratitudes,
            recurringNeeds: analysis.recurringNeeds,
            recurringPeople: analysis.recurringPeople,
            resurfacingMessage: analysis.resurfacingMessage,
            continuityPrompt: analysis.continuityPrompt,
            narrativeSummary: analysis.narrativeSummary,
            weekStats: analysis.weekStats
        )
    }

}
