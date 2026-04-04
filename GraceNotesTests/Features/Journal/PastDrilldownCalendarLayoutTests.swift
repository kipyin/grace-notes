import XCTest
@testable import GraceNotes

final class PastDrilldownCalendarLayoutTests: XCTestCase {

    private func gregorianCalendar(firstWeekday: Int = 1) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = firstWeekday
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Month banners in the feathered drill-down viewport must sit below the top fade so short
    /// (single-month) grids stay legible.
    func test_drilldownCalendarGrid_topScrollInset_coversTopFeatherBand_atPreferredViewport() {
        let viewport = ReviewHistoryDrilldownCalendarGrid.Metrics.scrollViewportHeight
        let featherTop = viewport * ReviewHistoryDrilldownCalendarGrid.Metrics.featherOpaqueStartsAt
        let inset = ReviewHistoryDrilldownCalendarGrid.scrollContentTopInset(forViewportHeight: viewport)
        XCTAssertGreaterThanOrEqual(inset + 0.5, featherTop)
    }

    func test_drilldownCalendarGrid_topScrollInset_scalesWithViewportHeight() {
        let shortViewport: CGFloat = 220
        let featherStart = ReviewHistoryDrilldownCalendarGrid.Metrics.featherOpaqueStartsAt
        let expectedInset = (shortViewport * featherStart).rounded(.up)
        XCTAssertEqual(
            ReviewHistoryDrilldownCalendarGrid.scrollContentTopInset(forViewportHeight: shortViewport),
            expectedInset,
            accuracy: 0.001
        )
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
        let februaryEntry = Journal(entryDate: midFeb)
        let januaryEntry = Journal(entryDate: earlyJan)
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

    func test_dayDisposition_matchedAndJournalNotMatchedAndEmpty() {
        let cal = gregorianCalendar()
        let rangeLower = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let rangeUpper = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let range = rangeLower ..< rangeUpper

        let matchedDay = cal.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let otherJournalDay = cal.date(from: DateComponents(year: 2026, month: 1, day: 11))!
        let emptyDay = cal.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let journalDays: Set<Date> = [
            cal.startOfDay(for: matchedDay),
            cal.startOfDay(for: otherJournalDay)
        ]
        let matching: Set<Date> = [cal.startOfDay(for: matchedDay)]

        XCTAssertEqual(
            ReviewHistoryDrilldownDayDisposition.resolve(
                dayStart: cal.startOfDay(for: matchedDay),
                historyDayRange: range,
                journalDaysInHistoryWindow: journalDays,
                matchingDayStarts: matching
            ),
            .matched
        )
        XCTAssertEqual(
            ReviewHistoryDrilldownDayDisposition.resolve(
                dayStart: cal.startOfDay(for: otherJournalDay),
                historyDayRange: range,
                journalDaysInHistoryWindow: journalDays,
                matchingDayStarts: matching
            ),
            .journalDayNotMatched
        )
        XCTAssertEqual(
            ReviewHistoryDrilldownDayDisposition.resolve(
                dayStart: cal.startOfDay(for: emptyDay),
                historyDayRange: range,
                journalDaysInHistoryWindow: journalDays,
                matchingDayStarts: matching
            ),
            .emptyHistoryDay
        )
    }

    func test_dayDisposition_outsideHistoryWindow() {
        let cal = gregorianCalendar()
        let rangeLower = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let rangeUpper = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let range = rangeLower ..< rangeUpper
        let paddingDay = cal.date(from: DateComponents(year: 2026, month: 1, day: 20))!

        XCTAssertEqual(
            ReviewHistoryDrilldownDayDisposition.resolve(
                dayStart: cal.startOfDay(for: paddingDay),
                historyDayRange: range,
                journalDaysInHistoryWindow: [],
                matchingDayStarts: []
            ),
            .outsideHistoryWindow
        )
    }

    func test_weekRowIdContaining_findsWeekForDay() {
        let cal = gregorianCalendar()
        let lower = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let upper = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let rows = ReviewHistoryDrilldownCalendarLayout.continuousRows(displayRange: lower ..< upper, calendar: cal)
        let midJanuary = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let rowId = ReviewHistoryDrilldownCalendarLayout.weekRowIdContaining(
            dayStart: midJanuary,
            rows: rows,
            calendar: cal
        )
        XCTAssertNotNil(rowId)
        XCTAssertTrue(rowId?.hasPrefix("week-") == true)
    }

    func test_weekRowIdContaining_returnsNilWhenDayOutsideGrid() {
        let cal = gregorianCalendar()
        let lower = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let upper = cal.date(from: DateComponents(year: 2026, month: 1, day: 8))!
        let rows = ReviewHistoryDrilldownCalendarLayout.continuousRows(displayRange: lower ..< upper, calendar: cal)
        let outside = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        XCTAssertNil(
            ReviewHistoryDrilldownCalendarLayout.weekRowIdContaining(dayStart: outside, rows: rows, calendar: cal)
        )
    }

    func test_sectionChipCountByMatchedDays_prefersFirstContributingRow() {
        let cal = gregorianCalendar()
        let day = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let dayStart = cal.startOfDay(for: day)
        let threeGratitudes = (0..<3).map { Entry(fullText: "\($0)") }
        let newer = Journal(entryDate: day, gratitudes: threeGratitudes, needs: [], people: [])
        let older = Journal(entryDate: day, gratitudes: [Entry(fullText: "solo")], needs: [], people: [])

        let countsNewestFirst = ReviewHistoryWindowing.sectionChipCountByMatchedDays(
            section: .gratitudes,
            matchingDayStarts: [dayStart],
            contributingEntriesNewestFirst: [newer, older],
            calendar: cal
        )
        XCTAssertEqual(countsNewestFirst[dayStart], 3)

        let countsOlderFirst = ReviewHistoryWindowing.sectionChipCountByMatchedDays(
            section: .gratitudes,
            matchingDayStarts: [dayStart],
            contributingEntriesNewestFirst: [older, newer],
            calendar: cal
        )
        XCTAssertEqual(countsOlderFirst[dayStart], 1)
    }

    func test_peekMetrics_clampedViewport_growsWithRemainingAbovePreferred() {
        let preferred = ReviewHistoryDrilldownCalendarGrid.Metrics.scrollViewportHeight
        let extra: CGFloat = 80
        let clamped = ReviewHistoryDrilldownPeekMetrics.clampedViewportHeight(remainingHeight: preferred + extra)
        XCTAssertEqual(clamped, preferred + extra, accuracy: 0.001)
    }

    func test_peekMetrics_clampedViewport_doesNotInflateWhenRemainingSmallerThanNotionalMinimum() {
        let minimum = ReviewHistoryDrilldownPeekMetrics.minimumViewportHeight
        let remaining = minimum - 10
        let clamped = ReviewHistoryDrilldownPeekMetrics.clampedViewportHeight(remainingHeight: remaining)
        XCTAssertEqual(clamped, remaining, accuracy: 0.001)
    }

    func test_peekMetrics_clampedViewport_clampsNegativeRemainingToZero() {
        let clamped = ReviewHistoryDrilldownPeekMetrics.clampedViewportHeight(remainingHeight: -40)
        XCTAssertEqual(clamped, 0, accuracy: 0.001)
    }

    func test_peekMetrics_clampedViewport_usesRemainingWhenBetweenMinAndPreferred() {
        let minimum = ReviewHistoryDrilldownPeekMetrics.minimumViewportHeight
        let preferred = ReviewHistoryDrilldownCalendarGrid.Metrics.scrollViewportHeight
        let target: CGFloat = minimum + (preferred - minimum) * 0.5
        let clamped = ReviewHistoryDrilldownPeekMetrics.clampedViewportHeight(remainingHeight: target)
        XCTAssertEqual(clamped, target, accuracy: 0.001)
    }
}
