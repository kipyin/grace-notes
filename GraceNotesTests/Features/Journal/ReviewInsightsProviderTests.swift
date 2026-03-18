import XCTest
@testable import GraceNotes

final class ReviewInsightsProviderTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        UserDefaults.standard.removeObject(forKey: ReviewInsightsProvider.useAIReviewInsightsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ReviewInsightsProvider.useAIReviewInsightsKey)
        super.tearDown()
    }

    func test_generateInsights_aiEnabled_returnsCloudInsightsWhenAvailable() async {
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.useAIReviewInsightsKey)
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

        XCTAssertEqual(insights.source, .cloudAI)
    }

    func test_generateInsights_aiDisabled_usesDeterministicInsights() async {
        UserDefaults.standard.set(false, forKey: ReviewInsightsProvider.useAIReviewInsightsKey)
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
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.useAIReviewInsightsKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(StubError.failed))
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

    func test_generateInsights_whenBothGeneratorsFail_usesWeekRangeFallback() async {
        UserDefaults.standard.set(true, forKey: ReviewInsightsProvider.useAIReviewInsightsKey)
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
    }

    private func makeInsights(source: ReviewInsightSource) -> ReviewInsights {
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        return ReviewInsights(
            source: source,
            generatedAt: now,
            weekStart: now,
            weekEnd: now,
            weeklyInsights: [],
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
