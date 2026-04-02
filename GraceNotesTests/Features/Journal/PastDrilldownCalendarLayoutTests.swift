import XCTest
@testable import GraceNotes

final class PastDrilldownCalendarLayoutTests: XCTestCase {

    private func gregorianCalendar(firstWeekday: Int = 1) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = firstWeekday
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func test_continuousRows_twoMonthSpan_insertsTwoBanners() {
        let cal = gregorianCalendar()
        let lower = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let upper = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let rows = ReviewHistoryDrilldownCalendarLayout.continuousRows(displayRange: lower ..< upper, calendar: cal)
        let banners = rows.compactMap { row -> String? in
            if case .monthBanner(_, let title) = row { return title }
            return nil
        }
        XCTAssertEqual(banners.count, 2)
        XCTAssertTrue(banners[0].contains("2026"))
        XCTAssertTrue(banners[1].contains("2026"))
    }

    func test_drilldownGridDisplayRange_usesFirstOfMonthForEarliestEntry() {
        let cal = gregorianCalendar()
        let upper = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let historyLower = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let historyRange = historyLower ..< upper
        let midFeb = cal.date(from: DateComponents(year: 2026, month: 2, day: 15))!
        let earlyJan = cal.date(from: DateComponents(year: 2026, month: 1, day: 20))!
        let februaryEntry = JournalEntry(entryDate: midFeb)
        let januaryEntry = JournalEntry(entryDate: earlyJan)
        let display = ReviewHistoryDrilldownCalendarLayout.drilldownGridDisplayRange(
            entries: [februaryEntry, januaryEntry],
            historyDayRange: historyRange,
            calendar: cal
        )
        let expectedLower = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        XCTAssertEqual(display.lowerBound, cal.startOfDay(for: expectedLower))
        XCTAssertEqual(display.upperBound, upper)
    }

    func test_continuousRows_singleDay_yieldsOneWeekRow() {
        let cal = gregorianCalendar()
        let day = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let next = cal.date(from: DateComponents(year: 2026, month: 6, day: 16))!
        let rows = ReviewHistoryDrilldownCalendarLayout.continuousRows(displayRange: day ..< next, calendar: cal)
        let weeks = rows.filter {
            if case .week = $0 { return true }
            return false
        }
        XCTAssertEqual(weeks.count, 1)
    }
}
