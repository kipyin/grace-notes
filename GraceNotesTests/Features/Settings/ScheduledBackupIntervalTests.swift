import XCTest
@testable import GraceNotes

final class ScheduledBackupIntervalTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar = cal
    }

    func test_off_neverDue() {
        XCTAssertFalse(ScheduledBackupInterval.off.isDue(lastRun: nil, now: Date(), calendar: calendar))
        XCTAssertFalse(ScheduledBackupInterval.off.isDue(lastRun: Date.distantPast, now: Date(), calendar: calendar))
    }

    func test_nonOff_nilLastRun_isDue() {
        let now = makeDate(year: 2026, month: 4, day: 4)
        XCTAssertTrue(ScheduledBackupInterval.daily.isDue(lastRun: nil, now: now, calendar: calendar))
        XCTAssertTrue(ScheduledBackupInterval.weekly.isDue(lastRun: nil, now: now, calendar: calendar))
    }

    func test_daily_sameCalendarDay_notDue() {
        let morning = makeDate(year: 2026, month: 4, day: 4, hour: 8)
        let evening = makeDate(year: 2026, month: 4, day: 4, hour: 22)
        XCTAssertFalse(ScheduledBackupInterval.daily.isDue(lastRun: morning, now: evening, calendar: calendar))
    }

    func test_daily_nextCalendarDay_isDue() {
        let priorDay = makeDate(year: 2026, month: 4, day: 4)
        let nextDay = makeDate(year: 2026, month: 4, day: 5)
        XCTAssertTrue(ScheduledBackupInterval.daily.isDue(lastRun: priorDay, now: nextDay, calendar: calendar))
    }

    func test_weekly_seventhDay_notDue_sixthDayFromStart() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let plus6 = makeDate(year: 2026, month: 1, day: 7)
        XCTAssertFalse(ScheduledBackupInterval.weekly.isDue(lastRun: start, now: plus6, calendar: calendar))
    }

    func test_weekly_eighthDayFromStart_isDue() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let plus7 = makeDate(year: 2026, month: 1, day: 8)
        XCTAssertTrue(ScheduledBackupInterval.weekly.isDue(lastRun: start, now: plus7, calendar: calendar))
    }

    func test_biweekly_fourteenthDayFromStart_notDue() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let plus13 = makeDate(year: 2026, month: 1, day: 14)
        XCTAssertFalse(ScheduledBackupInterval.biweekly.isDue(lastRun: start, now: plus13, calendar: calendar))
    }

    func test_biWeekly_fifteenthDayFromStart_isDue() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let plus14 = makeDate(year: 2026, month: 1, day: 15)
        XCTAssertTrue(ScheduledBackupInterval.biweekly.isDue(lastRun: start, now: plus14, calendar: calendar))
    }

    func test_monthly_thirtiethDayFromStart_notDue() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let plus29 = makeDate(year: 2026, month: 1, day: 30)
        XCTAssertFalse(ScheduledBackupInterval.monthly.isDue(lastRun: start, now: plus29, calendar: calendar))
    }

    func test_monthly_firstDayOfNextCalendarMonth_isDue() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let firstOfFebruary = makeDate(year: 2026, month: 2, day: 1)
        XCTAssertTrue(ScheduledBackupInterval.monthly.isDue(lastRun: start, now: firstOfFebruary, calendar: calendar))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        let parts = DateComponents(calendar: calendar, year: year, month: month, day: day, hour: hour)
        return calendar.date(from: parts)!
    }
}
