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

    func test_dayLabel_insideRollingInterval_usesAbbreviatedWeekday() {
        let reference = date(year: 2026, month: 3, day: 18)
        let oldest = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: reference))!
        let oldestStart = calendar.startOfDay(for: oldest)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))!
        let displayInterval = oldestStart..<endExclusive
        let mid = date(year: 2026, month: 3, day: 15)

        let label = ReviewRhythmFormatting.dayLabel(
            date: mid,
            displayInterval: displayInterval,
            calendar: calendar,
            referenceNow: reference
        )

        XCTAssertFalse(label.contains("/"))
        XCTAssertFalse(label.isEmpty)
        XCTAssertNotEqual(label, String(localized: "Today"))
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

    func test_dayLabel_outsideDisplayInterval_usesMonthDayDigits() {
        let reference = date(year: 2026, month: 3, day: 18)
        let oldest = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: reference))!
        let displayInterval = calendar.startOfDay(for: oldest)..<(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))!
        )
        let before = date(year: 2026, month: 3, day: 1)

        let label = ReviewRhythmFormatting.dayLabel(
            date: before,
            displayInterval: displayInterval,
            calendar: calendar,
            referenceNow: reference
        )

        XCTAssertNotNil(label.rangeOfCharacter(from: .decimalDigits))
        let shortWeekdaySymbols = Set(calendar.shortWeekdaySymbols)
        XCTAssertFalse(shortWeekdaySymbols.contains(label))
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
