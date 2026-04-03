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

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
