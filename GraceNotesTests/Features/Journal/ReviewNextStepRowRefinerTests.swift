import XCTest
@testable import GraceNotes

final class ReviewNextStepRowRefinerTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func test_nextStepText_emptyContinuityAndNoAction_returnsNil() {
        let weekStart = date(year: 2026, month: 4, day: 6)
        let insights = makeInsights(
            weekStart: weekStart,
            continuityPrompt: "",
            weeklyInsights: [
                ReviewWeeklyInsight(
                    pattern: .sparseFallback,
                    observation: "x",
                    action: nil,
                    primaryTheme: nil,
                    mentionCount: nil,
                    dayCount: 0
                )
            ],
            mostRecurring: []
        )
        let refiner = ReviewNextStepRowRefiner()
        XCTAssertNil(refiner.nextStepText(for: insights))
    }

    func test_nextStepText_gladHappened_returnsNil() {
        let weekStart = date(year: 2026, month: 4, day: 6)
        let glad = String(localized: "review.prompts.gladHappened")
        let insights = makeInsights(
            weekStart: weekStart,
            continuityPrompt: glad,
            weeklyInsights: [],
            mostRecurring: []
        )
        let refiner = ReviewNextStepRowRefiner()
        XCTAssertNil(refiner.nextStepText(for: insights))
    }

    func test_nextStepText_statsFirst_returnsNil_evenWithContinuity() {
        let weekStart = date(year: 2026, month: 4, day: 6)
        let insights = makeInsights(
            weekStart: weekStart,
            continuityPrompt: "Any next step line.",
            weeklyInsights: [],
            mostRecurring: [],
            presentationMode: .statsFirst
        )
        let refiner = ReviewNextStepRowRefiner()
        XCTAssertNil(refiner.nextStepText(for: insights))
    }

    func test_shouldShowNarrativeRow_statsFirst_false() {
        let weekStart = date(year: 2026, month: 4, day: 6)
        let insights = makeInsights(
            weekStart: weekStart,
            continuityPrompt: "Carry something forward.",
            weeklyInsights: [],
            mostRecurring: [],
            presentationMode: .statsFirst
        )
        XCTAssertFalse(ReviewNextStepRowRefiner.shouldShowNarrativeRow(insights: insights, isLoading: false))
    }

    func test_nextStepText_thinRecurringEcho_whenThemeMatchesTopRecurring_returnsNil() {
        let weekStart = date(year: 2026, month: 4, day: 6)
        let insights = makeInsights(
            weekStart: weekStart,
            continuityPrompt: "Short echo about Rest.",
            weeklyInsights: [
                ReviewWeeklyInsight(
                    pattern: .recurringTheme,
                    observation: "Rest showed up.",
                    action: "Short echo about Rest.",
                    primaryTheme: "Rest",
                    mentionCount: 3,
                    dayCount: 2
                )
            ],
            mostRecurring: [
                ReviewMostRecurringTheme(
                    canonicalConcept: "rest",
                    label: "Rest",
                    totalCount: 4,
                    dayCount: 3,
                    currentWeekCount: 3,
                    previousWeekCount: 1,
                    evidence: []
                )
            ]
        )
        let refiner = ReviewNextStepRowRefiner()
        XCTAssertNil(refiner.nextStepText(for: insights))
    }

    func test_nextStepText_longAction_whenThemeMatchesTopRecurring_returnsText() {
        let weekStart = date(year: 2026, month: 4, day: 6)
        let longAction = String(repeating: "Pick one small concrete step toward Rest this week. ", count: 5)
        XCTAssertGreaterThanOrEqual(longAction.count, 110)
        let insights = makeInsights(
            weekStart: weekStart,
            continuityPrompt: longAction,
            weeklyInsights: [
                ReviewWeeklyInsight(
                    pattern: .recurringTheme,
                    observation: "Rest showed up.",
                    action: longAction,
                    primaryTheme: "Rest",
                    mentionCount: 3,
                    dayCount: 2
                )
            ],
            mostRecurring: [
                ReviewMostRecurringTheme(
                    canonicalConcept: "rest",
                    label: "Rest",
                    totalCount: 4,
                    dayCount: 3,
                    currentWeekCount: 3,
                    previousWeekCount: 1,
                    evidence: []
                )
            ]
        )
        let refiner = ReviewNextStepRowRefiner()
        XCTAssertEqual(refiner.nextStepText(for: insights), longAction.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func test_shouldShowNarrativeRow_loading_true() {
        XCTAssertTrue(ReviewNextStepRowRefiner.shouldShowNarrativeRow(insights: nil, isLoading: true))
    }

    func test_shouldShowNarrativeRow_unlock_nilInsights_falseLoading() {
        XCTAssertTrue(ReviewNextStepRowRefiner.shouldShowNarrativeRow(insights: nil, isLoading: false))
    }

    func test_shouldShowNarrativeRow_whenNextStepNil_false() {
        let weekStart = date(year: 2026, month: 4, day: 6)
        let glad = String(localized: "review.prompts.gladHappened")
        let insights = makeInsights(
            weekStart: weekStart,
            continuityPrompt: glad,
            weeklyInsights: [],
            mostRecurring: []
        )
        XCTAssertFalse(ReviewNextStepRowRefiner.shouldShowNarrativeRow(insights: insights, isLoading: false))
    }

    // MARK: - Helpers

    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)!
    }

    private func makeInsights(
        weekStart: Date,
        continuityPrompt: String,
        weeklyInsights: [ReviewWeeklyInsight],
        mostRecurring: [ReviewMostRecurringTheme],
        presentationMode: ReviewPresentationMode = .insight
    ) -> ReviewInsights {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let weekStats = ReviewWeekStats(
            reflectionDays: 3,
            meaningfulEntryCount: 3,
            completionMix: ReviewWeekCompletionMix(
                soilDayCount: 0,
                sproutDayCount: 1,
                twigDayCount: 1,
                leafDayCount: 1,
                bloomDayCount: 0
            ),
            activity: [],
            rhythmHistory: nil,
            sectionTotals: ReviewWeekSectionTotals(gratitudeMentions: 1, needMentions: 1, peopleMentions: 0),
            historySectionTotals: ReviewWeekSectionTotals(gratitudeMentions: 1, needMentions: 1, peopleMentions: 0),
            historyCompletionMix: ReviewWeekCompletionMix(
                soilDayCount: 0,
                sproutDayCount: 0,
                twigDayCount: 0,
                leafDayCount: 0,
                bloomDayCount: 0
            ),
            mostRecurringThemes: mostRecurring,
            movementThemes: [],
            trendingBuckets: nil
        )
        return ReviewInsights(
            source: .deterministic,
            presentationMode: presentationMode,
            generatedAt: weekStart,
            weekStart: weekStart,
            weekEnd: weekEnd,
            weeklyInsights: weeklyInsights,
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: "",
            continuityPrompt: continuityPrompt,
            narrativeSummary: nil,
            weekStats: weekStats
        )
    }
}
