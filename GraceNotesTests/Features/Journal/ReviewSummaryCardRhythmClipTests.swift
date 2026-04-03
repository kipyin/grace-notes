import XCTest
@testable import GraceNotes

final class ReviewSummaryCardRhythmClipTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
    }

    func test_rollingRhythm_returnsEmptyWhenRawIsEmpty() {
        let reference = date(year: 2026, month: 3, day: 18)
        let refStart = calendar.startOfDay(for: reference)
        let (days, interval) = ReviewDaysYouWrotePanel.rollingRhythmDaysForDisplay(
            [],
            referenceNow: reference,
            calendar: calendar
        )
        XCTAssertTrue(days.isEmpty)
        XCTAssertEqual(interval.lowerBound, refStart)
        XCTAssertEqual(interval.upperBound, refStart)
    }

    func test_rollingRhythm_densePassThrough_preservesCountAndSortsOldestFirst() {
        let reference = date(year: 2026, month: 3, day: 18)
        let dayMarch10 = date(year: 2026, month: 3, day: 10)
        let dayMarch11 = date(year: 2026, month: 3, day: 11)
        let dayMarch12 = date(year: 2026, month: 3, day: 12)
        let raw = [
            ReviewDayActivity(date: dayMarch12, hasReflectiveActivity: true, hasPersistedEntry: true),
            ReviewDayActivity(date: dayMarch10, hasReflectiveActivity: false, hasPersistedEntry: true),
            ReviewDayActivity(date: dayMarch11, hasReflectiveActivity: false, hasPersistedEntry: false)
        ]
        let (days, interval) = ReviewDaysYouWrotePanel.rollingRhythmDaysForDisplay(
            raw,
            referenceNow: reference,
            calendar: calendar
        )
        XCTAssertEqual(days.count, 3)
        XCTAssertEqual(calendar.startOfDay(for: days[0].date), calendar.startOfDay(for: dayMarch10))
        XCTAssertEqual(calendar.startOfDay(for: days[1].date), calendar.startOfDay(for: dayMarch11))
        XCTAssertEqual(calendar.startOfDay(for: days[2].date), calendar.startOfDay(for: dayMarch12))
        XCTAssertEqual(interval.lowerBound, calendar.startOfDay(for: dayMarch10))
        let march12Start = calendar.startOfDay(for: dayMarch12)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: march12Start) else {
            XCTFail("expected end")
            return
        }
        XCTAssertEqual(interval.upperBound, endExclusive)
    }

    func test_rollingRhythm_duplicateCalendarDays_lastRowWins() {
        let reference = date(year: 2026, month: 3, day: 18)
        let day = date(year: 2026, month: 3, day: 10)
        let first = ReviewDayActivity(date: day, hasReflectiveActivity: false, hasPersistedEntry: false)
        let second = ReviewDayActivity(date: day, hasReflectiveActivity: false, hasPersistedEntry: true)
        let (days, _) = ReviewDaysYouWrotePanel.rollingRhythmDaysForDisplay(
            [first, second],
            referenceNow: reference,
            calendar: calendar
        )
        XCTAssertEqual(days.count, 1)
        XCTAssertTrue(days[0].hasPersistedEntry)
    }

    func test_rollingRhythm_singleHollowDay_isSingleColumn() {
        let reference = date(year: 2026, month: 3, day: 18)
        let hollow = ReviewDayActivity(
            date: date(year: 2026, month: 3, day: 10),
            hasReflectiveActivity: false,
            hasPersistedEntry: false
        )
        let (days, _) = ReviewDaysYouWrotePanel.rollingRhythmDaysForDisplay(
            [hollow],
            referenceNow: reference,
            calendar: calendar
        )
        XCTAssertEqual(days.count, 1)
        XCTAssertFalse(days[0].hasPersistedEntry)
        XCTAssertFalse(days[0].hasReflectiveActivity)
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
