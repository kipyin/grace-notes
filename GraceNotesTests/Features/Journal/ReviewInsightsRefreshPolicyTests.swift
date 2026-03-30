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

    private func makeKey(
        weekStart: Date = Date(timeIntervalSince1970: 0),
        snapshots: [ReviewEntrySnapshot] = [],
        weekBoundaryPreferenceRawValue: String = ReviewWeekBoundaryPreference.defaultValue.rawValue
    ) -> ReviewInsightsRefreshKey {
        ReviewInsightsRefreshKey(
            weekStart: weekStart,
            entrySnapshots: snapshots,
            weekBoundaryPreferenceRawValue: weekBoundaryPreferenceRawValue
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
                emptyDays: 0,
                startedDays: 1,
                growingDays: 0,
                balancedDays: 1,
                fullDays: 0
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
