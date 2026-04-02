import XCTest
@testable import GraceNotes

final class PastSearchDayCaptionTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
    }

    func test_today_usesLocalizedToday() {
        let now = date(year: 2026, month: 7, day: 15, hour: 12)
        let day = calendar.startOfDay(for: now)
        XCTAssertEqual(
            PastSearchDayCaption.string(day: day, now: now, calendar: calendar),
            String(localized: "Today")
        )
    }

    func test_yesterday_usesLocalizedYesterday() {
        let now = date(year: 2026, month: 7, day: 15, hour: 12)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        XCTAssertEqual(
            PastSearchDayCaption.string(day: yesterday, now: now, calendar: calendar),
            String(localized: "PastSearch.dateLabel.yesterday")
        )
    }

    func test_sameCalendarYear_omitsYear() {
        let now = date(year: 2026, month: 7, day: 15, hour: 12)
        let day = date(year: 2026, month: 3, day: 8, hour: 12)
        let locale = Locale(identifier: "en_US_POSIX")
        let caption = PastSearchDayCaption.string(
            day: day,
            now: now,
            calendar: calendar,
            dateFormattingLocale: locale
        )
        XCTAssertFalse(caption.contains("2026"), "Same-year caption should omit the year, got: \(caption)")
        XCTAssertTrue(
            caption.contains("8") || caption.contains("08"),
            "Caption should include day-of-month, got: \(caption)"
        )
    }

    func test_otherCalendarYear_includesYear() {
        let now = date(year: 2026, month: 7, day: 15, hour: 12)
        let day = date(year: 2024, month: 3, day: 8, hour: 12)
        let locale = Locale(identifier: "en_US_POSIX")
        let caption = PastSearchDayCaption.string(
            day: day,
            now: now,
            calendar: calendar,
            dateFormattingLocale: locale
        )
        XCTAssertTrue(caption.contains("2024"), "Expected year in caption, got: \(caption)")
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        guard let resolved = calendar.date(from: components) else {
            XCTFail("Invalid date")
            return Date()
        }
        return resolved
    }
}
