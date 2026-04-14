import XCTest
@testable import GraceNotes

final class ReviewWeekTrendPolicyTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    // MARK: - Warm-up phase detection

    /// Sun-start week Mar 15 … Mar 21, 2026; first two local days are Mar 15–16.
    func test_isWarmUpPhase_sundayStart_firstTwoDaysOnly() {
        calendar.firstWeekday = 1
        let reference = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)

        XCTAssertTrue(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: period,
                referenceDate: date(year: 2026, month: 3, day: 15),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: period,
                referenceDate: date(year: 2026, month: 3, day: 16),
                calendar: calendar
            )
        )
        XCTAssertFalse(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: period,
                referenceDate: date(year: 2026, month: 3, day: 17),
                calendar: calendar
            )
        )
    }

    /// Mon-start week Mar 16 … Mar 22, 2026; warm-up is Mar 16–17.
    func test_isWarmUpPhase_mondayStart_firstTwoDaysOnly() {
        calendar.firstWeekday = 2
        let reference = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)

        XCTAssertTrue(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: period,
                referenceDate: date(year: 2026, month: 3, day: 16),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: period,
                referenceDate: date(year: 2026, month: 3, day: 17),
                calendar: calendar
            )
        )
        XCTAssertFalse(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: period,
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
        )
    }

    /// Inverted `currentPeriod` (lowerBound > upperBound) must fail closed to non–warm-up.
    func test_isWarmUpPhase_invalidInvertedRange_returnsFalse() {
        calendar.firstWeekday = 1
        let dayStart = date(year: 2026, month: 3, day: 15)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let invertedPeriod = Range<Date>(uncheckedBounds: (nextDayStart, dayStart))
        let reference = calendar.date(byAdding: .hour, value: 14, to: dayStart)!

        XCTAssertFalse(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: invertedPeriod,
                referenceDate: reference,
                calendar: calendar
            )
        )
    }

    /// Empty half-open range (`lowerBound == upperBound`) must not be treated as warm-up.
    func test_isWarmUpPhase_emptyRange_returnsFalse() {
        calendar.firstWeekday = 1
        let dayStart = date(year: 2026, month: 3, day: 15)
        let emptyPeriod = dayStart..<dayStart
        let reference = calendar.date(byAdding: .hour, value: 14, to: dayStart)!

        XCTAssertFalse(
            ReviewWeekTrendPolicy.isWarmUpPhase(
                currentPeriod: emptyPeriod,
                referenceDate: reference,
                calendar: calendar
            )
        )
    }

    // MARK: - Surfacing trend (floors + warm-up exceptions)

    func test_rawTrend_matchesWeekOverWeekDirection() {
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: 0, previous: 0), .stable)
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: 1, previous: 0), .new)
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: 2, previous: 1), .rising)
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: 1, previous: 3), .down)
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: 2, previous: 2), .stable)
    }

    /// Invalid negative counts are treated as `.stable` so bad upstream data does not imply rising/down labels.
    func test_rawTrend_negativeCountsAreStable() {
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: -1, previous: 0), .stable)
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: 0, previous: -1), .stable)
        XCTAssertEqual(ReviewWeekTrendPolicy.rawTrend(current: -1, previous: -2), .stable)
    }

    func test_trendingSurfacingTrend_negativeCountsAreStable() {
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: -1, previous: 0, isWarmUpPhase: false),
            .stable
        )
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 0, previous: -1, isWarmUpPhase: false),
            .stable
        )
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: -1, previous: -2, isWarmUpPhase: true),
            .stable
        )
    }

    func test_trendingSurfacing_new_requiresCurrentAtLeastTwo() {
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 1, previous: 0, isWarmUpPhase: false),
            .stable
        )
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 2, previous: 0, isWarmUpPhase: false),
            .new
        )
    }

    func test_trendingSurfacing_rising_requiresCurrentAtLeastTwoAndIncrease() {
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 2, previous: 1, isWarmUpPhase: false),
            .rising
        )
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 1, previous: 0, isWarmUpPhase: false),
            .stable
        )
    }

    func test_trendingSurfacing_down_requiresPreviousAtLeastThreeAndDropAfterWarmUp() {
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 1, previous: 3, isWarmUpPhase: false),
            .down
        )
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 2, previous: 2, isWarmUpPhase: false),
            .stable
        )
    }

    /// During warm-up, “up” still surfaces when floors are met (exception: early rise).
    func test_trendingSurfacing_warmUpStillAllowsRisingWhenFloorsMet() {
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 2, previous: 1, isWarmUpPhase: true),
            .rising
        )
    }

    /// During warm-up, partial “down” (current > 0) is suppressed until balanced rules apply.
    func test_trendingSurfacing_warmUpSuppressesPartialDown() {
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 1, previous: 3, isWarmUpPhase: true),
            .stable
        )
    }

    /// Warm-up exception: allow down when previous was strong and current week mentions are zero.
    func test_trendingSurfacing_warmUpAllowsDownToZeroWhenPriorStrong() {
        XCTAssertEqual(
            ReviewWeekTrendPolicy.trendingSurfacingTrend(current: 0, previous: 3, isWarmUpPhase: true),
            .down
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
