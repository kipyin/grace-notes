import Foundation

struct ReviewInsightsProvider: Sendable {
    static let aiFeaturesEnabledKey = SummarizerProvider.useCloudUserDefaultsKey
    /// Legacy key removed by `migrateLegacyAIFeaturesToggleIfNeeded`;
    /// still consulted for install-continuity heuristics.
    static let legacyAIFeaturesUserDefaultsKey = "useAIReviewInsights"

    private let deterministicGenerator: any ReviewInsightsGenerating
    private let cloudGenerator: (any ReviewInsightsGenerating)?
    private let userDefaults: UserDefaults

    init(
        deterministicGenerator: any ReviewInsightsGenerating = DeterministicReviewInsightsGenerator(),
        cloudGenerator: (any ReviewInsightsGenerating)? = nil,
        apiKey: String = ApiSecrets.cloudApiKey,
        userDefaults: UserDefaults = .standard
    ) {
        self.deterministicGenerator = deterministicGenerator
        self.userDefaults = userDefaults

        if let cloudGenerator {
            self.cloudGenerator = cloudGenerator
        } else if ApiSecrets.isUsableCloudApiKey(apiKey) {
            self.cloudGenerator = CloudReviewInsightsGenerator(apiKey: apiKey)
        } else {
            self.cloudGenerator = nil
        }
    }

    static func migrateLegacyAIFeaturesToggleIfNeeded(defaults: UserDefaults = .standard) {
        guard let legacyValue = defaults.object(forKey: legacyAIFeaturesUserDefaultsKey) as? Bool else {
            return
        }
        let currentAIFeaturesValue = defaults.object(forKey: aiFeaturesEnabledKey) as? Bool ?? false
        defaults.set(currentAIFeaturesValue || legacyValue, forKey: aiFeaturesEnabledKey)
        defaults.removeObject(forKey: legacyAIFeaturesUserDefaultsKey)
    }

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar = .current
    ) async -> ReviewInsights {
        let useAI = AIFeaturesSettings.isEnabled(using: userDefaults)

        let cloudAllowed = ReviewInsightsCloudEligibility.hasMinimumEvidenceForCloudAI(
            entries: entries,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if useAI, cloudAllowed, let cloudGenerator,
           let cloudInsights = try? await cloudGenerator.generateInsights(
            from: entries,
            referenceDate: referenceDate,
            calendar: calendar
           ) {
            return cloudInsights
        }

        if let deterministicInsights = try? await deterministicGenerator.generateInsights(
            from: entries,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return deterministicInsights
        }

        return sparseFallbackInsights(referenceDate: referenceDate, calendar: calendar)
    }

    private func sparseFallbackInsights(referenceDate: Date, calendar: Calendar) -> ReviewInsights {
        let weekRange = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
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

    nonisolated(unsafe) static let shared = ReviewInsightsProvider()
}
