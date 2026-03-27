import XCTest
@testable import GraceNotes

final class ReviewRhythmFormattingTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
    }

    func test_dayLabel_dateInsideWeek_usesAbbreviatedWeekday() {
        let weekStart = date(year: 2026, month: 3, day: 21)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let midWeek = date(year: 2026, month: 3, day: 24)

        let label = ReviewRhythmFormatting.dayLabel(
            date: midWeek,
            currentWeek: weekStart..<weekEnd,
            calendar: calendar
        )

        XCTAssertFalse(
            label.contains("/"),
            "Weekday-in-week label should not use M/d numeric form; got \(label)"
        )
        XCTAssertFalse(label.isEmpty)
    }

    func test_dayLabel_dateOutsideWeek_usesMonthDayDigits() {
        let weekStart = date(year: 2026, month: 3, day: 21)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let beforeWeek = date(year: 2026, month: 3, day: 14)

        let label = ReviewRhythmFormatting.dayLabel(
            date: beforeWeek,
            currentWeek: weekStart..<weekEnd,
            calendar: calendar
        )

        XCTAssertTrue(label.contains("/"), "Expected locale M/d style with slash, got: \(label)")
    }

    func test_assetName_mapsAllCompletionLevels() {
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .empty), "empty")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .started), "started")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .growing), "growing")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .balanced), "balanced")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .full), "full")
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return calendar.date(from: c)!
    }
}
