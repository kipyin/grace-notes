import XCTest
@testable import GraceNotes

final class ReviewInsightsPeriodTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    /// Wednesday 2026-03-18; Sun-start week is Mar 15 … Mar 21.
    func test_currentPeriod_sundayStartWeek_containsReferenceWeek() {
        calendar.firstWeekday = 1
        let reference = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        XCTAssertEqual(period.lowerBound, date(year: 2026, month: 3, day: 15))
        XCTAssertEqual(period.upperBound, date(year: 2026, month: 3, day: 22))
    }

    func test_previousPeriod_sundayStart_isPriorWeek() {
        calendar.firstWeekday = 1
        let reference = date(year: 2026, month: 3, day: 18)
        let current = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: current, calendar: calendar)
        XCTAssertEqual(previous.lowerBound, date(year: 2026, month: 3, day: 8))
        XCTAssertEqual(previous.upperBound, date(year: 2026, month: 3, day: 15))
    }

    /// Wednesday 2026-03-18; Mon-start week is Mar 16 … Mar 22.
    func test_currentPeriod_mondayStartWeek_containsReferenceWeek() {
        calendar.firstWeekday = 2
        let reference = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        XCTAssertEqual(period.lowerBound, date(year: 2026, month: 3, day: 16))
        XCTAssertEqual(period.upperBound, date(year: 2026, month: 3, day: 23))
    }

    func test_previousPeriod_mondayStart_isPriorWeek() {
        calendar.firstWeekday = 2
        let reference = date(year: 2026, month: 3, day: 18)
        let current = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: current, calendar: calendar)
        XCTAssertEqual(previous.lowerBound, date(year: 2026, month: 3, day: 9))
        XCTAssertEqual(previous.upperBound, date(year: 2026, month: 3, day: 16))
    }

    func test_previousPeriod_upperBoundEqualsCurrentLowerBound() {
        calendar.firstWeekday = 1
        let reference = date(year: 2026, month: 3, day: 18)
        let current = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: current, calendar: calendar)
        XCTAssertEqual(previous.upperBound, current.lowerBound)
    }

    func test_currentPeriod_containsFirstDayOfWeek_atMidnight() {
        calendar.firstWeekday = 1
        let weekStart = date(year: 2026, month: 3, day: 15)
        let period = ReviewInsightsPeriod.currentPeriod(containing: weekStart, calendar: calendar)
        XCTAssertTrue(period.contains(weekStart))
        XCTAssertEqual(period.lowerBound, weekStart)
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
