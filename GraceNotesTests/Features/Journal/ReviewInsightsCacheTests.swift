import XCTest
@testable import GraceNotes

final class ReviewInsightsCacheTests: XCTestCase {
    private var calendar: Calendar!
    private var userDefaults: UserDefaults!
    private var cache: ReviewInsightsCache!

    private var defaultWeekBoundaryRaw: String {
        ReviewWeekBoundaryPreference.defaultValue.rawValue
    }

    private var defaultPastStatsToken: String {
        PastStatisticsIntervalSelection.default.cacheKeyToken
    }

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let suiteName = "ReviewInsightsCacheTests.\(UUID().uuidString)"
        // Clear disk for the suite, then allocate a fresh `UserDefaults` instance so in-memory
        // registration does not return stale empties across sequential actor reads/writes.
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        userDefaults = UserDefaults(suiteName: suiteName)!
        cache = ReviewInsightsCache(userDefaults: userDefaults)
    }
}

extension ReviewInsightsCacheTests {
    func test_storeAndLoad_roundTripsForMatchingWeek() async {
        let weekStart = date(year: 2026, month: 3, day: 12)
        let insights = sampleInsights(weekStart: weekStart)

        await cache.storeIfEligible(
            insights,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        let loaded = await cache.insights(
            forWeekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )

        XCTAssertEqual(loaded, insights)
    }

    func test_store_skipsSparseProviderFallback() async {
        let weekStart = date(year: 2026, month: 3, day: 12)
        let sparse = sparseFallbackInsights(weekStart: weekStart)

        await cache.storeIfEligible(
            sparse,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        let loaded = await cache.insights(
            forWeekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )

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
                presentationMode: insights.presentationMode,
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
                weekStats: insights.weekStats
            )
            await cache.storeIfEligible(
                insights,
                calendar: calendar,
                weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
                pastStatisticsIntervalToken: defaultPastStatsToken
            )
        }

        let oldest = weekStarts[0]
        let newestEight = Array(weekStarts.suffix(8))

        let oldestLoaded = await cache.insights(
            forWeekStart: oldest,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        XCTAssertNil(oldestLoaded)
        for weekStart in newestEight {
            let loaded = await cache.insights(
                forWeekStart: weekStart,
                calendar: calendar,
                weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
                pastStatisticsIntervalToken: defaultPastStatsToken
            )
            XCTAssertNotNil(loaded)
        }
    }

    func test_load_doesNotCrossReadWhenWeekBoundaryPreferenceDiffers() async {
        let weekStart = date(year: 2026, month: 3, day: 12)
        let insights = sampleInsights(weekStart: weekStart)

        await cache.storeIfEligible(
            insights,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: ReviewWeekBoundaryPreference.sundayStart.rawValue,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        let loadedOtherBoundary = await cache.insights(
            forWeekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: ReviewWeekBoundaryPreference.mondayStart.rawValue,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        XCTAssertNil(loadedOtherBoundary)

        let loadedSameBoundary = await cache.insights(
            forWeekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: ReviewWeekBoundaryPreference.sundayStart.rawValue,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        XCTAssertEqual(loadedSameBoundary, insights)
    }

    func test_JSONEncoder_roundTripReviewInsights() throws {
        let insights = sampleInsights(weekStart: date(year: 2026, month: 3, day: 12))
        let data = try JSONEncoder().encode(insights)
        let decoded = try JSONDecoder().decode(ReviewInsights.self, from: data)
        XCTAssertEqual(decoded, insights)
    }

    func test_ReviewWeekStats_JSON_roundTrip_preservesHistoryRollups() throws {
        let weekStart = date(year: 2026, month: 3, day: 12)
        let stats = sampleWeekStats(weekStart: weekStart)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(ReviewWeekStats.self, from: data)
        XCTAssertEqual(decoded.historySectionTotals, stats.historySectionTotals)
        XCTAssertEqual(decoded.historyCompletionMix, stats.historyCompletionMix)
        XCTAssertEqual(decoded, stats)
    }

    func test_cache_storeAndLoad_preservesHistoryRollupsOnWeekStats() async {
        let weekStart = date(year: 2026, month: 3, day: 12)
        let insights = sampleInsights(weekStart: weekStart)

        await cache.storeIfEligible(
            insights,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        let loaded = await cache.insights(
            forWeekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )

        XCTAssertEqual(loaded?.weekStats.historySectionTotals, insights.weekStats.historySectionTotals)
        XCTAssertEqual(loaded?.weekStats.historyCompletionMix, insights.weekStats.historyCompletionMix)
    }
}

extension ReviewInsightsCacheTests {
    func test_ReviewWeekStats_decodesOmittedHistoryRollupsAsZeros() throws {
        let json = """
        {
          "reflectionDays": 2,
          "meaningfulEntryCount": 2,
          "completionMix": {
            "emptyDays": 0,
            "startedDays": 1,
            "growingDays": 0,
            "balancedDays": 1,
            "fullDays": 0
          },
          "activity": [],
          "sectionTotals": {
            "gratitudeMentions": 2,
            "needMentions": 1,
            "peopleMentions": 0
          },
          "mostRecurringThemes": [],
          "movementThemes": [],
          "trendingBuckets": { "new": [], "up": [], "down": [] }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let stats = try JSONDecoder().decode(ReviewWeekStats.self, from: data)
        XCTAssertEqual(stats.sectionTotals.gratitudeMentions, 2)
        XCTAssertEqual(stats.historySectionTotals.gratitudeMentions, 0)
        XCTAssertEqual(stats.historyCompletionMix.soilDayCount, 0)
        XCTAssertEqual(stats.historyCompletionMix.sproutDayCount, 0)
        XCTAssertEqual(stats.historyCompletionMix.twigDayCount, 0)
        XCTAssertEqual(stats.historyCompletionMix.leafDayCount, 0)
        XCTAssertEqual(stats.historyCompletionMix.bloomDayCount, 0)
    }

    func test_ReviewWeekCompletionMix_totalDaysRepresented_sumsBuckets() {
        let mix = ReviewWeekCompletionMix(
            soilDayCount: 2,
            sproutDayCount: 1,
            twigDayCount: 3,
            leafDayCount: 0,
            bloomDayCount: 4
        )
        XCTAssertEqual(mix.totalDaysRepresented, 10)
    }

    func test_ReviewWeekCompletionMix_decodesLegacySoilSeedKeyedPayload() throws {
        let json = """
        {"soilDays":1,"seedDays":2,"ripeningDays":3,"harvestDays":4,"abundanceDays":5}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let mix = try JSONDecoder().decode(ReviewWeekCompletionMix.self, from: data)
        XCTAssertEqual(mix.soilDayCount, 1)
        XCTAssertEqual(mix.sproutDayCount, 2)
        XCTAssertEqual(mix.twigDayCount, 0)
        XCTAssertEqual(mix.leafDayCount, 3)
        XCTAssertEqual(mix.bloomDayCount, 9)
    }

    func test_ReviewMostRecurringTheme_decodesIgnoringLegacyTrendKey() throws {
        let json = """
        {
          "label": "Rest",
          "totalCount": 4,
          "dayCount": 2,
          "currentWeekCount": 3,
          "previousWeekCount": 1,
          "trend": "rising",
          "evidence": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let theme = try JSONDecoder().decode(ReviewMostRecurringTheme.self, from: data)
        XCTAssertEqual(theme.label, "Rest")
        XCTAssertEqual(theme.totalCount, 4)
        XCTAssertEqual(theme.currentWeekCount, 3)
        XCTAssertEqual(theme.previousWeekCount, 1)
        XCTAssertTrue(theme.evidence.isEmpty)
    }

    func test_corruptedPayload_clearsAndAllowsStore() async {
        // Must stay aligned with `ReviewInsightsCache` persisted payload key (v2).
        let payloadKey = "GraceNotes.reviewInsightsByWeek.v2"
        userDefaults.set(Data([0xFF, 0xFE, 0xFD]), forKey: payloadKey)

        let weekStart = date(year: 2026, month: 3, day: 12)
        let beforeHeal = await cache.insights(
            forWeekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        XCTAssertNil(beforeHeal)

        let insights = sampleInsights(weekStart: weekStart)
        await cache.storeIfEligible(
            insights,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        let afterStore = await cache.insights(
            forWeekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: defaultWeekBoundaryRaw,
            pastStatisticsIntervalToken: defaultPastStatsToken
        )
        XCTAssertEqual(afterStore, insights)
    }
}

extension ReviewInsightsCacheTests {
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
            presentationMode: .insight,
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
            weekStats: sampleWeekStats(weekStart: weekStart)
        )
    }

    private func sparseFallbackInsights(weekStart: Date) -> ReviewInsights {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        return ReviewInsights(
            source: .deterministic,
            presentationMode: .statsFirst,
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
            weekStats: sampleWeekStats(weekStart: weekStart)
        )
    }

    private func sampleWeekStats(weekStart: Date) -> ReviewWeekStats {
        ReviewWeekStats(
            reflectionDays: 2,
            meaningfulEntryCount: 2,
            completionMix: ReviewWeekCompletionMix(
                soilDayCount: 0,
                sproutDayCount: 1,
                twigDayCount: 0,
                leafDayCount: 1,
                bloomDayCount: 0
            ),
            activity: [
                ReviewDayActivity(date: weekStart, hasReflectiveActivity: true, hasPersistedEntry: true),
                ReviewDayActivity(
                    date: calendar.date(byAdding: .day, value: 1, to: weekStart)!,
                    hasReflectiveActivity: true,
                    hasPersistedEntry: true
                )
            ],
            rhythmHistory: nil,
            sectionTotals: ReviewWeekSectionTotals(
                gratitudeMentions: 2,
                needMentions: 1,
                peopleMentions: 0
            ),
            historySectionTotals: ReviewWeekSectionTotals(
                gratitudeMentions: 5,
                needMentions: 3,
                peopleMentions: 1
            ),
            historyCompletionMix: ReviewWeekCompletionMix(
                soilDayCount: 1,
                sproutDayCount: 0,
                twigDayCount: 2,
                leafDayCount: 0,
                bloomDayCount: 1
            )
        )
    }
}
