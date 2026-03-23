import Foundation

struct ReviewInsightsProvider: Sendable {
    static let useAIReviewInsightsKey = "useAIReviewInsights"

    private let deterministicGenerator: any ReviewInsightsGenerating
    private let cloudGenerator: (any ReviewInsightsGenerating)?

    init(
        deterministicGenerator: any ReviewInsightsGenerating = DeterministicReviewInsightsGenerator(),
        cloudGenerator: (any ReviewInsightsGenerating)? = nil,
        apiKey: String = ApiSecrets.cloudApiKey
    ) {
        self.deterministicGenerator = deterministicGenerator

        if let cloudGenerator {
            self.cloudGenerator = cloudGenerator
        } else if ApiSecrets.isUsableCloudApiKey(apiKey) {
            self.cloudGenerator = CloudReviewInsightsGenerator(apiKey: apiKey)
        } else {
            self.cloudGenerator = nil
        }
    }

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar = .current
    ) async -> ReviewInsights {
        let useAI = UserDefaults.standard.bool(forKey: Self.useAIReviewInsightsKey)

        let cloudAllowed = ReviewInsightsCloudEligibility.hasMinimumEvidenceForCloudAI(
            entries: entries,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if useAI, cloudAllowed, let cloudGenerator {
            if let cloudInsights = try? await cloudGenerator.generateInsights(
                from: entries,
                referenceDate: referenceDate,
                calendar: calendar
            ) {
                return cloudInsights
            }
        }

        if let deterministicInsights = try? await deterministicGenerator.generateInsights(
            from: entries,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return deterministicInsights
        }

        let weekRange = weekDateRange(containing: referenceDate, calendar: calendar)
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
            narrativeSummary: nil
        )
    }

    private func weekDateRange(containing date: Date, calendar: Calendar) -> Range<Date> {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return start..<end
    }

    nonisolated(unsafe) static let shared = ReviewInsightsProvider()
}
