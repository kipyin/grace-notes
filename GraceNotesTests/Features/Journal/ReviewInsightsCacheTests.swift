import XCTest
@testable import GraceNotes

final class ReviewInsightsCacheTests: XCTestCase {
    private var calendar: Calendar!
    private var userDefaults: UserDefaults!
    private var cache: ReviewInsightsCache!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let suiteName = "ReviewInsightsCacheTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        cache = ReviewInsightsCache(userDefaults: userDefaults)
    }

    func test_storeAndLoad_roundTripsForMatchingWeek() async {
        let weekStart = date(year: 2026, month: 3, day: 12)
        let insights = sampleInsights(weekStart: weekStart)

        await cache.storeIfEligible(insights, calendar: calendar)
        let loaded = await cache.insights(forWeekStart: weekStart, calendar: calendar)

        XCTAssertEqual(loaded, insights)
    }

    func test_store_skipsSparseProviderFallback() async {
        let weekStart = date(year: 2026, month: 3, day: 12)
        let sparse = sparseFallbackInsights(weekStart: weekStart)

        await cache.storeIfEligible(sparse, calendar: calendar)
        let loaded = await cache.insights(forWeekStart: weekStart, calendar: calendar)

        XCTAssertNil(loaded)
    }

    func test_prune_dropsOldestWeeksBeyondLimit() async {
        // Cache keeps 8 weeks; the 9th store should evict the earliest weekStart by key, not by generatedAt.
        var weekStarts: [Date] = []
        for offset in 0..<9 {
            let start = date(year: 2026, month: 1, day: 5)
            let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: start)!
            weekStarts.append(weekStart)
        }

        for (index, weekStart) in weekStarts.enumerated() {
            var insights = sampleInsights(weekStart: weekStart)
            insights = ReviewInsights(
                source: insights.source,
                generatedAt: calendar.date(byAdding: .hour, value: index, to: weekStart)!,
                weekStart: insights.weekStart,
                weekEnd: insights.weekEnd,
                weeklyInsights: insights.weeklyInsights,
                recurringGratitudes: insights.recurringGratitudes,
                recurringNeeds: insights.recurringNeeds,
                recurringPeople: insights.recurringPeople,
                resurfacingMessage: insights.resurfacingMessage,
                continuityPrompt: insights.continuityPrompt,
                narrativeSummary: insights.narrativeSummary,
                cloudSkippedReason: insights.cloudSkippedReason
            )
            await cache.storeIfEligible(insights, calendar: calendar)
        }

        let oldest = weekStarts[0]
        let newestEight = Array(weekStarts.suffix(8))

        let oldestLoaded = await cache.insights(forWeekStart: oldest, calendar: calendar)
        XCTAssertNil(oldestLoaded)
        for weekStart in newestEight {
            let loaded = await cache.insights(forWeekStart: weekStart, calendar: calendar)
            XCTAssertNotNil(loaded)
        }
    }

    func test_JSONEncoder_roundTripReviewInsights() throws {
        let insights = sampleInsights(weekStart: date(year: 2026, month: 3, day: 12))
        let data = try JSONEncoder().encode(insights)
        let decoded = try JSONDecoder().decode(ReviewInsights.self, from: data)
        XCTAssertEqual(decoded, insights)
    }

    func test_JSONEncoder_roundTrip_preservesGranularCloudSkippedReason() throws {
        let insights = sampleInsights(weekStart: date(year: 2026, month: 3, day: 12))
            .withCloudSkippedReason(.cloudInsightQualityCheckFailed)
        let data = try JSONEncoder().encode(insights)
        let decoded = try JSONDecoder().decode(ReviewInsights.self, from: data)
        XCTAssertEqual(decoded.cloudSkippedReason, .cloudInsightQualityCheckFailed)
    }

    func test_corruptedPayload_clearsAndAllowsStore() async {
        // Must stay aligned with `ReviewInsightsCache.payloadKey`.
        let payloadKey = "GraceNotes.reviewInsightsByWeek.v1"
        userDefaults.set(Data([0xFF, 0xFE, 0xFD]), forKey: payloadKey)

        let weekStart = date(year: 2026, month: 3, day: 12)
        let beforeHeal = await cache.insights(forWeekStart: weekStart, calendar: calendar)
        XCTAssertNil(beforeHeal)

        let insights = sampleInsights(weekStart: weekStart)
        await cache.storeIfEligible(insights, calendar: calendar)
        let afterStore = await cache.insights(forWeekStart: weekStart, calendar: calendar)
        XCTAssertEqual(afterStore, insights)
    }

    // MARK: - Helpers

    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)!
    }

    private func sampleInsights(weekStart: Date) -> ReviewInsights {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        return ReviewInsights(
            source: .deterministic,
            generatedAt: weekStart,
            weekStart: weekStart,
            weekEnd: weekEnd,
            weeklyInsights: [
                ReviewWeeklyInsight(
                    pattern: .recurringTheme,
                    observation: "You wrote about calm several times.",
                    action: "Notice when calm shows up again.",
                    primaryTheme: "calm",
                    mentionCount: 3,
                    dayCount: 2
                )
            ],
            recurringGratitudes: [ReviewInsightTheme(label: "Walks", count: 2)],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: "A thread from your week.",
            continuityPrompt: "One small next step.",
            narrativeSummary: "A gentle arc.",
            cloudSkippedReason: nil
        )
    }

    private func sparseFallbackInsights(weekStart: Date) -> ReviewInsights {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        return ReviewInsights(
            source: .deterministic,
            generatedAt: weekStart,
            weekStart: weekStart,
            weekEnd: weekEnd,
            weeklyInsights: [
                ReviewWeeklyInsight(
                    pattern: .sparseFallback,
                    observation: "Keep going.",
                    action: nil,
                    primaryTheme: nil,
                    mentionCount: nil,
                    dayCount: 0
                )
            ],
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: "",
            continuityPrompt: "",
            narrativeSummary: nil,
            cloudSkippedReason: nil
        )
    }
}
