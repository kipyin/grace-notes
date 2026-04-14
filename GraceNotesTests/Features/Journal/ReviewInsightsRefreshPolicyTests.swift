import XCTest
@testable import GraceNotes

final class ReviewInsightsRefreshPolicyTests: XCTestCase {
    func test_shouldRefresh_whenNoInsights_returnsTrue() {
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            hasInsights: false,
            previousKey: makeKey(),
            currentKey: makeKey()
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenKeyUnchanged_returnsFalse() {
        let key = makeKey()
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            hasInsights: true,
            previousKey: key,
            currentKey: key
        )

        XCTAssertFalse(result)
    }

    func test_shouldRefresh_whenEntrySnapshotChanges_returnsTrue() {
        let entryID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let previous = makeKey(
            snapshots: [ReviewEntrySnapshot(id: entryID, updatedAt: Date(timeIntervalSince1970: 100))]
        )
        let current = makeKey(
            snapshots: [ReviewEntrySnapshot(id: entryID, updatedAt: Date(timeIntervalSince1970: 200))]
        )
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            hasInsights: true,
            previousKey: previous,
            currentKey: current
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenWeekBoundaryPreferenceChanges_returnsTrue() {
        let previous = makeKey(weekBoundaryPreferenceRawValue: ReviewWeekBoundaryPreference.sundayStart.rawValue)
        let current = makeKey(weekBoundaryPreferenceRawValue: ReviewWeekBoundaryPreference.mondayStart.rawValue)
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            hasInsights: true,
            previousKey: previous,
            currentKey: current
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenPastStatisticsIntervalChanges_returnsTrue() {
        let custom = PastStatisticsIntervalSelection(mode: .custom, quantity: 2, unit: .week).cacheKeyToken
        let previous = makeKey(pastStatisticsIntervalToken: custom)
        let current = makeKey(pastStatisticsIntervalToken: PastStatisticsIntervalSelection.default.cacheKeyToken)
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            hasInsights: true,
            previousKey: previous,
            currentKey: current
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenThemeSubstitutionRulesRevisionChanges_returnsTrue() {
        let previous = makeKey(themeSubstitutionRulesRevision: 0)
        let current = makeKey(themeSubstitutionRulesRevision: 1)
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            hasInsights: true,
            previousKey: previous,
            currentKey: current
        )
        XCTAssertTrue(result)
    }

    /// Past-tab insights read older days inside the past-statistics window; refresh fingerprints must
    /// include those rows, not only the current review week (PR #166 review feedback).
    func test_entrySnapshotsAffectingInsights_includesHistoryWindowEntryOutsideCurrentWeek() {
        let ctx = sundayUTCReviewContext()
        let olderDay = utcDate(year: 2026, month: 3, day: 5, calendar: ctx.calendar)
        XCTAssertTrue(ctx.currentPeriod.contains(ctx.reference))
        XCTAssertFalse(ctx.currentPeriod.contains(olderDay))

        let historyOnlyId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let historyOnly = Journal(
            id: historyOnlyId,
            entryDate: olderDay,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let thisWeekId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let thisWeek = Journal(
            id: thisWeekId,
            entryDate: utcDate(year: 2026, month: 3, day: 17, calendar: ctx.calendar),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let snapshots = ReviewInsightsRefreshKey.entrySnapshotsAffectingInsights(
            entries: [historyOnly, thisWeek],
            referenceDate: ctx.reference,
            calendar: ctx.calendar,
            pastStatisticsInterval: ctx.interval,
            currentReviewPeriod: ctx.currentPeriod
        )
        XCTAssertEqual(Set(snapshots.map(\.id)), Set([historyOnlyId, thisWeekId]))
    }

    func test_shouldRefresh_whenOnlyHistoryWindowEntryUpdatedAtChanges_returnsTrue() {
        let ctx = sundayUTCReviewContext()
        let olderDay = utcDate(year: 2026, month: 3, day: 5, calendar: ctx.calendar)
        let historyOnly = Journal(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            entryDate: olderDay,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let thisWeek = Journal(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            entryDate: utcDate(year: 2026, month: 3, day: 17, calendar: ctx.calendar),
            updatedAt: Date(timeIntervalSince1970: 400)
        )
        let entries = [historyOnly, thisWeek]
        let snapshotsBefore = ReviewInsightsRefreshKey.entrySnapshotsAffectingInsights(
            entries: entries,
            referenceDate: ctx.reference,
            calendar: ctx.calendar,
            pastStatisticsInterval: ctx.interval,
            currentReviewPeriod: ctx.currentPeriod
        )
        historyOnly.updatedAt = Date(timeIntervalSince1970: 900)
        let snapshotsAfter = ReviewInsightsRefreshKey.entrySnapshotsAffectingInsights(
            entries: entries,
            referenceDate: ctx.reference,
            calendar: ctx.calendar,
            pastStatisticsInterval: ctx.interval,
            currentReviewPeriod: ctx.currentPeriod
        )
        XCTAssertNotEqual(snapshotsBefore, snapshotsAfter)

        let token = ctx.interval.cacheKeyToken
        let weekBoundary = ReviewWeekBoundaryPreference.sundayStart.rawValue
        let keyBefore = ReviewInsightsRefreshKey(
            weekStart: ctx.currentPeriod.lowerBound,
            entrySnapshots: snapshotsBefore,
            weekBoundaryPreferenceRawValue: weekBoundary,
            pastStatisticsIntervalToken: token,
            themeOverrideRevision: 0,
            surfaceThemeAdjustmentRevision: 0
        )
        let keyAfter = ReviewInsightsRefreshKey(
            weekStart: ctx.currentPeriod.lowerBound,
            entrySnapshots: snapshotsAfter,
            weekBoundaryPreferenceRawValue: weekBoundary,
            pastStatisticsIntervalToken: token,
            themeOverrideRevision: 0,
            surfaceThemeAdjustmentRevision: 0
        )
        XCTAssertTrue(
            ReviewInsightsRefreshPolicy.shouldRefresh(hasInsights: true, previousKey: keyBefore, currentKey: keyAfter)
        )
    }

    func test_isSparseProviderFallback_matchesProviderFallbackShape() {
        XCTAssertTrue(ReviewInsightsRefreshPolicy.isSparseProviderFallback(makeSparseProviderFallbackInsights()))
    }

    func test_isSparseProviderFallback_falseWhenRecurringThemesPresent() {
        var insights = makeSparseProviderFallbackInsights()
        insights = ReviewInsights(
            source: insights.source,
            presentationMode: insights.presentationMode,
            generatedAt: insights.generatedAt,
            weekStart: insights.weekStart,
            weekEnd: insights.weekEnd,
            weeklyInsights: insights.weeklyInsights,
            recurringGratitudes: [ReviewInsightTheme(label: "Family", count: 2)],
            recurringNeeds: insights.recurringNeeds,
            recurringPeople: insights.recurringPeople,
            resurfacingMessage: insights.resurfacingMessage,
            continuityPrompt: insights.continuityPrompt,
            narrativeSummary: insights.narrativeSummary,
            weekStats: insights.weekStats
        )
        XCTAssertFalse(ReviewInsightsRefreshPolicy.isSparseProviderFallback(insights))
    }

    private func utcDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    /// Wednesday 2026-03-18 UTC; Sun-start week per ``ReviewInsightsPeriodTests``.
    private func sundayUTCReviewContext() -> SundayUTCReviewContext {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        let reference = utcDate(year: 2026, month: 3, day: 18, calendar: calendar)
        let currentPeriod = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        let interval = PastStatisticsIntervalSelection(mode: .custom, quantity: 4, unit: .week)
        return SundayUTCReviewContext(
            calendar: calendar,
            reference: reference,
            currentPeriod: currentPeriod,
            interval: interval
        )
    }

    private struct SundayUTCReviewContext {
        let calendar: Calendar
        let reference: Date
        let currentPeriod: Range<Date>
        let interval: PastStatisticsIntervalSelection
    }

    private func makeKey(
        weekStart: Date = Date(timeIntervalSince1970: 0),
        snapshots: [ReviewEntrySnapshot] = [],
        weekBoundaryPreferenceRawValue: String = ReviewWeekBoundaryPreference.defaultValue.rawValue,
        pastStatisticsIntervalToken: String = PastStatisticsIntervalSelection.default.cacheKeyToken,
        themeOverrideRevision: UInt64 = 0,
        surfaceThemeAdjustmentRevision: UInt64 = 0,
        themeSubstitutionRulesRevision: UInt64 = 0
    ) -> ReviewInsightsRefreshKey {
        ReviewInsightsRefreshKey(
            weekStart: weekStart,
            entrySnapshots: snapshots,
            weekBoundaryPreferenceRawValue: weekBoundaryPreferenceRawValue,
            pastStatisticsIntervalToken: pastStatisticsIntervalToken,
            themeOverrideRevision: themeOverrideRevision,
            surfaceThemeAdjustmentRevision: surfaceThemeAdjustmentRevision,
            themeSubstitutionRulesRevision: themeSubstitutionRulesRevision
        )
    }

    private func makeSparseProviderFallbackInsights() -> ReviewInsights {
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let fallbackInsight = ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: "Start with one reflection today to build your weekly review.",
            action: "What feels most important to carry into next week?",
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: 0
        )
        return ReviewInsights(
            source: .deterministic,
            presentationMode: .statsFirst,
            generatedAt: now,
            weekStart: now,
            weekEnd: now,
            weeklyInsights: [fallbackInsight],
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: fallbackInsight.observation,
            continuityPrompt: fallbackInsight.action ?? "",
            narrativeSummary: nil,
            weekStats: sampleWeekStats(now)
        )
    }

    private func sampleWeekStats(_ weekStart: Date) -> ReviewWeekStats {
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
            activity: [ReviewDayActivity(date: weekStart, hasReflectiveActivity: true, hasPersistedEntry: true)],
            rhythmHistory: nil,
            sectionTotals: ReviewWeekSectionTotals(
                gratitudeMentions: 2,
                needMentions: 1,
                peopleMentions: 0
            )
        )
    }
}
