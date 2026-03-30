import Foundation

struct ReviewInsightsProvider: Sendable {
    /// Legacy key from cloud-insight builds; still consulted for install-continuity heuristics.
    static let legacyAIFeaturesUserDefaultsKey = "useAIReviewInsights"

    private let deterministicGenerator: any ReviewInsightsGenerating
    private let aggregatesBuilder = WeeklyReviewAggregatesBuilder()

    init(
        deterministicGenerator: any ReviewInsightsGenerating = DeterministicReviewInsightsGenerator()
    ) {
        self.deterministicGenerator = deterministicGenerator
    }

    /// Legacy migration no longer needed now that review insights are deterministic-only.
    static func migrateLegacyAIFeaturesToggleIfNeeded(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: legacyAIFeaturesUserDefaultsKey)
    }

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar = .current
    ) async -> ReviewInsights {
        return await deterministicOrSparseInsights(
            from: entries,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private func deterministicOrSparseInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) async -> ReviewInsights {
        if let deterministicInsights = try? await deterministicGenerator.generateInsights(
            from: entries,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return deterministicInsights
        }

        return sparseFallbackInsights(
            from: entries,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private func sparseFallbackInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) -> ReviewInsights {
        let weekRange = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previousPeriod = ReviewInsightsPeriod.previousPeriod(before: weekRange, calendar: calendar)
        let currentWeekEntries = entries.filter { weekRange.contains($0.entryDate) }
        let previousWeekEntries = entries.filter { previousPeriod.contains($0.entryDate) }
        let aggregates = aggregatesBuilder.build(
            currentPeriod: weekRange,
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )
        let fallbackInsight = ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: String(
                localized: "Start with one reflection today to build your weekly review."
            ),
            action: String(
                localized: "What feels most important to carry into next week?"
            ),
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: 0
        )
        return ReviewInsights(
            source: .deterministic,
            presentationMode: .statsFirst,
            generatedAt: referenceDate,
            weekStart: weekRange.lowerBound,
            weekEnd: weekRange.upperBound,
            weeklyInsights: [fallbackInsight],
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: fallbackInsight.observation,
            continuityPrompt: fallbackInsight.action ?? String(
                localized: "What feels most important to carry into next week?"
            ),
            narrativeSummary: nil,
            weekStats: aggregates.stats
        )
    }

    nonisolated(unsafe) static let shared = ReviewInsightsProvider()
}
