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

    /// Covers the January 1 + `date(byAdding: .month, …)` path in `gregorianUTCMonthStart(for:)`, used when
    /// `dateInterval(of: .month, …)` and `date(from:)` for day=1 both fail but year/month are still known.
    /// That full chain is hard to force in a deterministic test; `gregorianUTCMonthStartFromYearMonth` is the
    /// extracted implementation and is what we assert here.
    func test_gregorianUTCMonthStartFromYearMonth_anchorsFromJanuaryFirst() {
        let fallback = date(year: 2026, month: 3, day: 15)
        let result = HistoryEntryGrouping.gregorianUTCMonthStartFromYearMonth(
            year: 2026,
            month: 3,
            calendar: calendar,
            fallbackDate: fallback
        )
        XCTAssertEqual(result, date(year: 2026, month: 3, day: 1))
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
