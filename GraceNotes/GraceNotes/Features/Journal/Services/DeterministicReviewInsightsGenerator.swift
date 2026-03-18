import Foundation

struct DeterministicReviewInsightsGenerator: ReviewInsightsGenerating {
    private let ruleEngine = WeeklyInsightRuleEngine()

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar = .current
    ) async throws -> ReviewInsights {
        let currentWeekRange = weekDateRange(containing: referenceDate, calendar: calendar)
        let previousWeekRange = previousWeekDateRange(from: currentWeekRange, calendar: calendar)
        let currentWeekEntries = entries.filter { currentWeekRange.contains($0.entryDate) }
        let previousWeekEntries = entries.filter { previousWeekRange.contains($0.entryDate) }
        let analysis = ruleEngine.analyze(
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            calendar: calendar
        )

        return ReviewInsights(
            source: .deterministic,
            generatedAt: referenceDate,
            weekStart: currentWeekRange.lowerBound,
            weekEnd: currentWeekRange.upperBound,
            weeklyInsights: analysis.weeklyInsights,
            recurringGratitudes: analysis.recurringGratitudes,
            recurringNeeds: analysis.recurringNeeds,
            recurringPeople: analysis.recurringPeople,
            resurfacingMessage: analysis.resurfacingMessage,
            continuityPrompt: analysis.continuityPrompt,
            narrativeSummary: analysis.narrativeSummary
        )
    }

    private func weekDateRange(containing date: Date, calendar: Calendar) -> Range<Date> {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return start..<end
    }

    private func previousWeekDateRange(from currentWeekRange: Range<Date>, calendar: Calendar) -> Range<Date> {
        let previousStart = calendar.date(byAdding: .day, value: -7, to: currentWeekRange.lowerBound)
            ?? currentWeekRange.lowerBound
        return previousStart..<currentWeekRange.lowerBound
    }
}
