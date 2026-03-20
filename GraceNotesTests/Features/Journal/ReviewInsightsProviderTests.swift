import XCTest
@testable import GraceNotes

final class ReviewInsightsProviderTests: XCTestCase {
    private static let legacyAIReviewInsightsKey = "useAIReviewInsights"
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        UserDefaults.standard.removeObject(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyAIReviewInsightsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyAIReviewInsightsKey)
        super.tearDown()
    }

    func test_generateInsights_aiEnabled_returnsCloudInsightsWhenAvailable() async {
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(
            result: .success(
                makeInsights(
                    source: .cloudAI,
                    weeklyInsights: [
                        ReviewWeeklyInsight(
                            pattern: .recurringTheme,
                            observation: "Cloud observation",
                            action: "Cloud action",
                            primaryTheme: "Rest",
                            mentionCount: 3,
                            dayCount: 2
                        )
                    ]
                )
            )
        )
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud
        )

        let insights = await provider.generateInsights(
            from: [],
            referenceDate: Date(timeIntervalSince1970: 1_742_147_200),
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .cloudAI)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "Cloud observation")
    }

    func test_generateInsights_aiDisabled_usesDeterministicInsights() async {
        UserDefaults.standard.set(false, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .success(makeInsights(source: .cloudAI)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud
        )

        let insights = await provider.generateInsights(
            from: [],
            referenceDate: Date(timeIntervalSince1970: 1_742_147_200),
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
    }

    func test_generateInsights_aiFailure_fallsBackToDeterministicInsights() async {
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let deterministic = StubReviewInsightsGenerator(
            result: .success(
                makeInsights(
                    source: .deterministic,
                    weeklyInsights: [
                        ReviewWeeklyInsight(
                            pattern: .recurringTheme,
                            observation: "Deterministic observation",
                            action: "Deterministic action",
                            primaryTheme: "Rest",
                            mentionCount: 2,
                            dayCount: 2
                        )
                    ]
                )
            )
        )
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud
        )

        let insights = await provider.generateInsights(
            from: [],
            referenceDate: Date(timeIntervalSince1970: 1_742_147_200),
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "Deterministic observation")
    }

    func test_generateInsights_whenBothGeneratorsFail_usesWeekRangeFallback() async {
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let deterministic = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud
        )
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let expectedWeekStart = date(year: 2026, month: 3, day: 16)
        let expectedWeekEnd = date(year: 2026, month: 3, day: 23)

        let insights = await provider.generateInsights(
            from: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weekStart, expectedWeekStart)
        XCTAssertEqual(insights.weekEnd, expectedWeekEnd)
        XCTAssertEqual(insights.weeklyInsights.first?.pattern, .sparseFallback)
        XCTAssertEqual(
            insights.weeklyInsights.first?.observation,
            "Start with one reflection today to build your weekly review."
        )
        XCTAssertEqual(
            insights.weeklyInsights.first?.action,
            "What feels most important to carry into next week?"
        )
    }

    func test_generateInsights_aiEnabled_withoutCurrentWeekContent_returnsDeterministicStarterInsight() async {
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: DeterministicReviewInsightsGenerator(),
            cloudGenerator: cloud
        )
        let previousWeekEntry = JournalEntry(
            entryDate: date(year: 2026, month: 3, day: 10),
            gratitudes: [JournalItem(fullText: "Family", chipLabel: "Family")]
        )

        let insights = await provider.generateInsights(
            from: [previousWeekEntry],
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weeklyInsights.first?.pattern, .sparseFallback)
        XCTAssertEqual(
            insights.weeklyInsights.first?.observation,
            "Start with one reflection today to build your weekly review."
        )
    }

    func test_migrateLegacyAIFeaturesToggle_whenLegacyTrue_setsUnifiedKeyAndClearsLegacy() {
        UserDefaults.standard.set(true, forKey: Self.legacyAIReviewInsightsKey)
        UserDefaults.standard.removeObject(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)

        ReviewInsightsProvider.migrateLegacyAIFeaturesToggleIfNeeded()

        let unifiedValue = UserDefaults.standard.object(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey) as? Bool
        let legacyValue = UserDefaults.standard.object(forKey: Self.legacyAIReviewInsightsKey) as? Bool
        XCTAssertEqual(unifiedValue, true)
        XCTAssertNil(legacyValue)
    }

    func test_migrateLegacyAIFeaturesToggle_whenUnifiedAlreadyTrue_keepsTrue() {
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        UserDefaults.standard.set(false, forKey: Self.legacyAIReviewInsightsKey)

        ReviewInsightsProvider.migrateLegacyAIFeaturesToggleIfNeeded()

        let unifiedValue = UserDefaults.standard.object(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey) as? Bool
        XCTAssertEqual(unifiedValue, true)
    }

    private func makeInsights(
        source: ReviewInsightSource,
        weeklyInsights: [ReviewWeeklyInsight] = []
    ) -> ReviewInsights {
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        return ReviewInsights(
            source: source,
            generatedAt: now,
            weekStart: now,
            weekEnd: now,
            weeklyInsights: weeklyInsights,
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: "message",
            continuityPrompt: "prompt",
            narrativeSummary: nil
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}

private enum StubError: Error {
    case failed
}

private struct StubReviewInsightsGenerator: ReviewInsightsGenerating {
    let result: Result<ReviewInsights, Error>

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) async throws -> ReviewInsights {
        try result.get()
    }
}
