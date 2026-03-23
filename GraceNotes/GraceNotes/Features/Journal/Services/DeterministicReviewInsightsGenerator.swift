import Foundation

struct DeterministicReviewInsightsGenerator: ReviewInsightsGenerating {
    private let ruleEngine = WeeklyInsightRuleEngine()

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar = .current
    ) async throws -> ReviewInsights {
        let currentPeriod = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previousPeriod = ReviewInsightsPeriod.previousPeriod(before: currentPeriod, calendar: calendar)
        let currentWeekEntries = entries.filter { currentPeriod.contains($0.entryDate) }
        let previousWeekEntries = entries.filter { previousPeriod.contains($0.entryDate) }
        let analysis = ruleEngine.analyze(
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            calendar: calendar
        )

        return ReviewInsights(
            source: .deterministic,
            generatedAt: referenceDate,
            weekStart: currentPeriod.lowerBound,
            weekEnd: currentPeriod.upperBound,
            weeklyInsights: analysis.weeklyInsights,
            recurringGratitudes: analysis.recurringGratitudes,
            recurringNeeds: analysis.recurringNeeds,
            recurringPeople: analysis.recurringPeople,
            resurfacingMessage: analysis.resurfacingMessage,
            continuityPrompt: analysis.continuityPrompt,
            narrativeSummary: analysis.narrativeSummary
        )
    }

}
