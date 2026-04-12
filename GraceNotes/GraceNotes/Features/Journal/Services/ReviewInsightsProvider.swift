import Foundation
import os

private let reviewInsightsProviderLogger = Logger(
    subsystem: Bundle(for: PersistenceController.self).bundleIdentifier ?? "GraceNotes",
    category: "ReviewInsightsProvider"
)

struct ReviewInsightsProvider: Sendable {
    /// Legacy UserDefaults key from cloud-enabled builds;
    /// ``migrateLegacyAIFeaturesToggleIfNeeded`` removes it for a clean slate.
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
        from entries: [Journal],
        referenceDate: Date,
        calendar: Calendar = .current,
        pastStatisticsInterval: PastStatisticsIntervalSelection = .default
    ) async -> ReviewInsights {
        return await deterministicOrSparseInsights(
            from: entries,
            referenceDate: referenceDate,
            calendar: calendar,
            pastStatisticsInterval: pastStatisticsInterval
        )
    }

    private func deterministicOrSparseInsights(
        from entries: [Journal],
        referenceDate: Date,
        calendar: Calendar,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) async -> ReviewInsights {
        do {
            return try await deterministicGenerator.generateInsights(
                from: entries,
                referenceDate: referenceDate,
                calendar: calendar,
                pastStatisticsInterval: pastStatisticsInterval
            )
        } catch {
            if !(error is CancellationError) {
                let detail = error.localizedDescription
                reviewInsightsProviderLogger.error(
                    "Sparse fallback after generator failure. \(detail, privacy: .public)"
                )
            }
            return sparseFallbackInsights(
                from: entries,
                referenceDate: referenceDate,
                calendar: calendar,
                pastStatisticsInterval: pastStatisticsInterval
            )
        }
    }

    private func sparseFallbackInsights(
        from entries: [Journal],
        referenceDate: Date,
        calendar: Calendar,
        pastStatisticsInterval: PastStatisticsIntervalSelection
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
            referenceDate: referenceDate,
            pastStatisticsInterval: pastStatisticsInterval
        )
        let carryIntoNextWeek = String(localized: "review.prompts.carryIntoNextWeek")
        let fallbackInsight = ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: String(
                localized: "review.insights.starterReflection"
            ),
            action: carryIntoNextWeek,
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
            continuityPrompt: carryIntoNextWeek,
            narrativeSummary: nil,
            weekStats: aggregates.stats
        )
    }

    nonisolated(unsafe) static let shared = ReviewInsightsProvider()
}
