import XCTest
@testable import GraceNotes

final class ReviewInsightsPeriodTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func test_currentPeriod_sevenDaysEndingOnReferenceDay() {
        let reference = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        XCTAssertEqual(period.lowerBound, date(year: 2026, month: 3, day: 12))
        XCTAssertEqual(period.upperBound, date(year: 2026, month: 3, day: 19))
    }

    func test_previousPeriod_isSevenDaysBeforeCurrentLowerBound() {
        let reference = date(year: 2026, month: 3, day: 18)
        let current = ReviewInsightsPeriod.currentPeriod(containing: reference, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: current, calendar: calendar)
        XCTAssertEqual(previous.lowerBound, date(year: 2026, month: 3, day: 5))
        XCTAssertEqual(previous.upperBound, date(year: 2026, month: 3, day: 12))
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
