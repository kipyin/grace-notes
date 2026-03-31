import XCTest
@testable import GraceNotes

final class ReviewWeekStatsPresentationTests: XCTestCase {
    func test_sectionTotalRows_orderAndCounts_matchSectionTotals() {
        let totals = ReviewWeekSectionTotals(gratitudeMentions: 12, needMentions: 4, peopleMentions: 7)
        let rows = ReviewWeekStatsPresentation.sectionTotalRows(from: totals)

        XCTAssertEqual(rows.map(\.section), [.gratitudes, .needs, .people])
        XCTAssertEqual(rows.map(\.count), [12, 4, 7])
    }

    func test_completionMixRows_orderAndCounts_matchCompletionMix() {
        let mix = ReviewWeekCompletionMix(
            emptyDays: 2,
            startedDays: 0,
            growingDays: 1,
            balancedDays: 3,
            fullDays: 0
        )
        let rows = ReviewWeekStatsPresentation.completionMixRows(from: mix)

        XCTAssertEqual(rows.map(\.level), [.empty, .started, .growing, .balanced, .full])
        XCTAssertEqual(rows.map(\.count), [2, 0, 1, 3, 0])
    }

    func test_presentationRows_alignWithReviewWeekStatsFixture() {
        let sectionTotals = ReviewWeekSectionTotals(gratitudeMentions: 3, needMentions: 2, peopleMentions: 1)
        let completionMix = ReviewWeekCompletionMix(
            emptyDays: 1,
            startedDays: 1,
            growingDays: 0,
            balancedDays: 0,
            fullDays: 0
        )
        let stats = ReviewWeekStats(
            reflectionDays: 2,
            meaningfulEntryCount: 2,
            completionMix: completionMix,
            activity: [],
            rhythmHistory: nil,
            sectionTotals: sectionTotals,
            mostRecurringThemes: [],
            movementThemes: [],
            trendingBuckets: nil
        )

        let sectionRows = ReviewWeekStatsPresentation.sectionTotalRows(from: stats.sectionTotals)
        XCTAssertEqual(sectionRows[0].count, stats.sectionTotals.gratitudeMentions)
        XCTAssertEqual(sectionRows[1].count, stats.sectionTotals.needMentions)
        XCTAssertEqual(sectionRows[2].count, stats.sectionTotals.peopleMentions)

        let mixRows = ReviewWeekStatsPresentation.completionMixRows(from: stats.completionMix)
        XCTAssertEqual(mixRows[0].count, stats.completionMix.emptyDays)
        XCTAssertEqual(mixRows[1].count, stats.completionMix.startedDays)
        XCTAssertEqual(mixRows[2].count, stats.completionMix.growingDays)
        XCTAssertEqual(mixRows[3].count, stats.completionMix.balancedDays)
        XCTAssertEqual(mixRows[4].count, stats.completionMix.fullDays)
    }
}
