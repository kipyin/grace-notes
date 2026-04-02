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

    func test_weekdaySymbolsOrdered_rotatesWithFirstWeekday() {
        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.firstWeekday = 1
        sundayFirst.timeZone = TimeZone(secondsFromGMT: 0)!
        sundayFirst.locale = Locale(identifier: "en_US_POSIX")
        let sunOrder = ReviewHistoryDrilldownCalendarLayout.weekdaySymbolsOrdered(calendar: sundayFirst)
        XCTAssertFalse(sunOrder.isEmpty)
        XCTAssertEqual(sunOrder.first, sundayFirst.shortWeekdaySymbols.first)

        var mondayFirst = Calendar(identifier: .gregorian)
        mondayFirst.firstWeekday = 2
        mondayFirst.timeZone = TimeZone(secondsFromGMT: 0)!
        mondayFirst.locale = Locale(identifier: "en_US_POSIX")
        let monOrder = ReviewHistoryDrilldownCalendarLayout.weekdaySymbolsOrdered(calendar: mondayFirst)
        XCTAssertEqual(monOrder.count, sunOrder.count)
        let mondaySymbols = mondayFirst.shortWeekdaySymbols
        XCTAssertGreaterThanOrEqual(mondaySymbols.count, 2)
        XCTAssertEqual(monOrder.first, mondaySymbols[1])
        XCTAssertEqual(Set(monOrder), Set(sunOrder))
    }

    /// January 1, 2026 is a Thursday (US: weekday 5 when Sunday is 1). Leading empty cells should match `firstWeekday`.
    func test_continuousRows_leadingPadding_respectsFirstWeekday() {
        let lower = gregorianCalendar(firstWeekday: 1)
            .date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let upper = gregorianCalendar(firstWeekday: 1)
            .date(from: DateComponents(year: 2026, month: 1, day: 8))!
        let calSunday = gregorianCalendar(firstWeekday: 1)
        let rowsSun = ReviewHistoryDrilldownCalendarLayout.continuousRows(
            displayRange: lower ..< upper,
            calendar: calSunday
        )
        guard case .week(_, let firstWeekSun) = rowsSun.first(where: {
            if case .week = $0 { return true }
            return false
        }) else {
            XCTFail("Expected a week row")
            return
        }
        let leadingSun = firstWeekSun.prefix(while: { $0 == nil }).count
        XCTAssertEqual(leadingSun, 4)

        let calMonday = gregorianCalendar(firstWeekday: 2)
        let rowsMon = ReviewHistoryDrilldownCalendarLayout.continuousRows(
            displayRange: lower ..< upper,
            calendar: calMonday
        )
        guard case .week(_, let firstWeekMon) = rowsMon.first(where: {
            if case .week = $0 { return true }
            return false
        }) else {
            XCTFail("Expected a week row")
            return
        }
        let leadingMon = firstWeekMon.prefix(while: { $0 == nil }).count
        XCTAssertEqual(leadingMon, 3)
    }
}
