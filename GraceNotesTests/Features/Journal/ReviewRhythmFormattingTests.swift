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

    func test_dayLabel_referenceDay_usesToday() {
        let reference = date(year: 2026, month: 3, day: 18)
        let oldest = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: reference))!
        let displayInterval = calendar.startOfDay(for: oldest)..<(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))!
        )

        let label = ReviewRhythmFormatting.dayLabel(
            date: reference,
            displayInterval: displayInterval,
            calendar: calendar,
            referenceNow: reference
        )

        XCTAssertEqual(label, String(localized: "Today"))
    }

    func test_dayLabel_withinPastSevenDays_usesAbbreviatedWeekday() {
        let reference = date(year: 2026, month: 3, day: 18)
        let mid = date(year: 2026, month: 3, day: 15)
        let displayInterval = calendar.startOfDay(for: date(year: 2026, month: 1, day: 1))..<(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))!
        )

        let label = ReviewRhythmFormatting.dayLabel(
            date: mid,
            displayInterval: displayInterval,
            calendar: calendar,
            referenceNow: reference
        )

        let weekdaySymbols = Set(calendar.shortWeekdaySymbols)
        XCTAssertTrue(weekdaySymbols.contains(label), "Expected weekday token, got: \(label)")
    }

    func test_dayLabel_beforePastSevenDays_usesNumericSlashedMonthDay() {
        let reference = date(year: 2026, month: 3, day: 18)
        let older = date(year: 2026, month: 3, day: 1)
        let displayInterval = calendar.startOfDay(for: older)..<(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))!
        )

        let label = ReviewRhythmFormatting.dayLabel(
            date: older,
            displayInterval: displayInterval,
            calendar: calendar,
            referenceNow: reference
        )

        XCTAssertTrue(label.contains("/"), "Expected M/d style label, got: \(label)")
        XCTAssertFalse(label.contains("Nov"), "Expected numeric month, got: \(label)")
        let weekdaySymbols = Set(calendar.shortWeekdaySymbols)
        XCTAssertFalse(weekdaySymbols.contains(label))
    }

    func test_dayLabel_priorCalendarYearFromReference_usesNumericDate() {
        let reference = date(year: 2026, month: 4, day: 3)
        let day2025 = date(year: 2025, month: 12, day: 10)
        let displayInterval = calendar.startOfDay(for: day2025)..<(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))!
        )

        let label = ReviewRhythmFormatting.dayLabel(
            date: day2025,
            displayInterval: displayInterval,
            calendar: calendar,
            referenceNow: reference
        )

        XCTAssertTrue(label.contains("12") && label.contains("10"), "Expected 12/10 style, got: \(label)")
        XCTAssertTrue(label.contains("/"))
    }

    func test_isLocalDayInPastSevenCalendarDaysEndingReference_boundary() {
        let reference = date(year: 2026, month: 3, day: 18)
        let oldestInWindow = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: reference))!
        )
        let beforeWindow = calendar.date(byAdding: .day, value: -1, to: oldestInWindow)!
        XCTAssertTrue(
            ReviewRhythmFormatting.isLocalDayInPastSevenCalendarDaysEndingReference(
                dayStart: oldestInWindow,
                referenceNow: reference,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            ReviewRhythmFormatting.isLocalDayInPastSevenCalendarDaysEndingReference(
                dayStart: beforeWindow,
                referenceNow: reference,
                calendar: calendar
            )
        )
    }

    func test_assetName_mapsAllCompletionLevels() {
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .soil), "soil")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .sprout), "sprout")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .twig), "twig")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .leaf), "leaf")
        XCTAssertEqual(ReviewRhythmFormatting.assetName(for: .bloom), "bloom")
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }
}
