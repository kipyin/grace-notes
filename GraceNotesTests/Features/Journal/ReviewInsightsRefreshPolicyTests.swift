import XCTest
@testable import GraceNotes

final class ReviewInsightsRefreshPolicyTests: XCTestCase {
    func test_shouldRefresh_whenForceTrue_returnsTrue() {
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: true,
            hasInsights: true,
            previousKey: makeKey(),
            currentKey: makeKey()
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenNoInsights_returnsTrue() {
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: false,
            hasInsights: false,
            previousKey: makeKey(),
            currentKey: makeKey()
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenKeyUnchanged_returnsFalse() {
        let key = makeKey()
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: false,
            hasInsights: true,
            previousKey: key,
            currentKey: key
        )

        XCTAssertFalse(result)
    }

    func test_shouldRefresh_whenAISettingChanges_returnsTrue() {
        let previous = makeKey(aiFeaturesEnabled: false)
        let current = makeKey(aiFeaturesEnabled: true)
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: false,
            hasInsights: true,
            previousKey: previous,
            currentKey: current
        )

        XCTAssertTrue(result)
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
            force: false,
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
            weekStats: insights.weekStats,
            cloudSkippedReason: insights.cloudSkippedReason
        )
        XCTAssertFalse(ReviewInsightsRefreshPolicy.isSparseProviderFallback(insights))
    }

    func test_forcedRefreshOutcome_nilPrevious_appliesGenerated() {
        let generated = makeSparseProviderFallbackInsights()
        let outcome = ReviewInsightsRefreshPolicy.forcedRefreshOutcome(previous: nil, generated: generated)
        XCTAssertEqual(outcome.insights, generated)
        XCTAssertTrue(outcome.shouldUpdateCachedRefreshKey)
    }

    func test_forcedRefreshOutcome_preservesRichWhenGeneratedIsSparseFallback() {
        let previous = makeRichInsights()
        let generated = makeSparseProviderFallbackInsights()
        let outcome = ReviewInsightsRefreshPolicy.forcedRefreshOutcome(previous: previous, generated: generated)
        XCTAssertEqual(outcome.insights, previous)
        XCTAssertFalse(outcome.shouldUpdateCachedRefreshKey)
    }

    func test_forcedRefreshOutcome_replacesWhenBothRich() {
        let previous = makeRichInsights()
        let generated = makeRichInsights(observation: "Updated observation")
        let outcome = ReviewInsightsRefreshPolicy.forcedRefreshOutcome(previous: previous, generated: generated)
        XCTAssertEqual(outcome.insights, generated)
        XCTAssertTrue(outcome.shouldUpdateCachedRefreshKey)
    }

    private func makeKey(
        weekStart: Date = Date(timeIntervalSince1970: 0),
        aiFeaturesEnabled: Bool = false,
        snapshots: [ReviewEntrySnapshot] = []
    ) -> ReviewInsightsRefreshKey {
        ReviewInsightsRefreshKey(
            weekStart: weekStart,
            aiFeaturesEnabled: aiFeaturesEnabled,
            entrySnapshots: snapshots
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
            weekStats: sampleWeekStats(now),
            cloudSkippedReason: nil
        )
    }

    private func makeRichInsights(observation: String = "You noted rest often this week.") -> ReviewInsights {
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let insight = ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: observation,
            action: "Try a short walk.",
            primaryTheme: "Rest",
            mentionCount: 3,
            dayCount: 2
        )
        return ReviewInsights(
            source: .cloudAI,
            presentationMode: .insight,
            generatedAt: now,
            weekStart: now,
            weekEnd: now,
            weeklyInsights: [insight],
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: "Resurfacing",
            continuityPrompt: "Continuity",
            narrativeSummary: nil,
            weekStats: sampleWeekStats(now),
            cloudSkippedReason: nil
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
            activity: [ReviewDayActivity(date: weekStart, hasReflectiveActivity: true)],
            sectionTotals: ReviewWeekSectionTotals(
                gratitudeMentions: 2,
                needMentions: 1,
                peopleMentions: 0
            )
        )
    }
}
