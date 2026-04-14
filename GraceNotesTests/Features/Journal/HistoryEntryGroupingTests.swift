import XCTest
@testable import GraceNotes

final class HistoryEntryGroupingTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func test_groupedByMonth_groupsEntriesAndSortsMonthsDescending() {
        let marchEntry = Journal(entryDate: date(year: 2026, month: 3, day: 17))
        let januaryEntry = Journal(entryDate: date(year: 2026, month: 1, day: 5))
        let februaryEntry = Journal(entryDate: date(year: 2026, month: 2, day: 28))

        let grouped = HistoryEntryGrouping.groupedByMonth(
            entries: [januaryEntry, marchEntry, februaryEntry],
            calendar: calendar
        )

        XCTAssertEqual(grouped.count, 3)
        XCTAssertEqual(grouped[0].key, date(year: 2026, month: 3, day: 1))
        XCTAssertEqual(grouped[1].key, date(year: 2026, month: 2, day: 1))
        XCTAssertEqual(grouped[2].key, date(year: 2026, month: 1, day: 1))
    }

    func test_groupedByMonth_keepsMultipleEntriesInSameMonth() {
        let firstMarchEntry = Journal(entryDate: date(year: 2026, month: 3, day: 1))
        let secondMarchEntry = Journal(entryDate: date(year: 2026, month: 3, day: 20))

        let grouped = HistoryEntryGrouping.groupedByMonth(
            entries: [firstMarchEntry, secondMarchEntry],
            calendar: calendar
        )

        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].entries.count, 2)
    }

    /// When both month-interval and Y/M normalization fail, production uses `startOfDay` instead of
    /// the raw entry timestamp so same-day entries stay in one bucket. Dual-nil combinations are
    /// rare in `Foundation`, so this injects the same key function as that fallback branch.
    func test_groupedByMonth_collapsesSameDayEntriesWhenMonthKeyFallsBackToStartOfDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = Journal(
            entryDate: date(
                components: DateComponents(year: 2026, month: 3, day: 9, hour: 8, minute: 0, second: 0),
                calendar: cal
            )
        )
        let evening = Journal(
            entryDate: date(
                components: DateComponents(year: 2026, month: 3, day: 9, hour: 22, minute: 30, second: 0),
                calendar: cal
            )
        )

        let grouped = HistoryEntryGrouping.groupedByMonth(
            entries: [morning, evening],
            calendar: cal,
            monthKeyResolver: { date, calendar in calendar.startOfDay(for: date) }
        )

        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].entries.count, 2)
        XCTAssertEqual(grouped[0].key, cal.startOfDay(for: morning.entryDate))
    }

    /// Locks first-of-month section keys for a real-world style calendar and non-UTC timezone
    /// (DST-safe same calendar month for varied times on one day).
    func test_groupedByMonth_usesStableMonthKeysWithLosAngelesTimeZone() {
        let previousDefaultTimeZone = NSTimeZone.default
        guard let laTimeZone = TimeZone(identifier: "America/Los_Angeles") else {
            XCTFail("Missing America/Los_Angeles timezone")
            return
        }
        NSTimeZone.default = laTimeZone
        defer { NSTimeZone.default = previousDefaultTimeZone }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = laTimeZone

        let morning = date(
            components: DateComponents(year: 2026, month: 3, day: 9, hour: 8, minute: 0, second: 0),
            calendar: cal
        )
        let evening = date(
            components: DateComponents(year: 2026, month: 3, day: 9, hour: 22, minute: 30, second: 0),
            calendar: cal
        )

        let grouped = HistoryEntryGrouping.groupedByMonth(
            entries: [Journal(entryDate: evening), Journal(entryDate: morning)],
            calendar: cal
        )

        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].entries.count, 2)
        XCTAssertEqual(
            grouped[0].key,
            date(components: DateComponents(year: 2026, month: 3, day: 1), calendar: cal)
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

    private func date(components: DateComponents, calendar cal: Calendar) -> Date {
        var merged = components
        merged.calendar = cal
        merged.timeZone = cal.timeZone
        return cal.date(from: merged)!
    }
}
