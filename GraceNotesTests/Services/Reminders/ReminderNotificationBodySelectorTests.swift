import XCTest
@testable import GraceNotes

final class ReminderNotificationBodySelectorTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    func test_timeBucket_reminderHour_selectsSegments() {
        let morning = date(hour: 8)
        XCTAssertEqual(
            ReminderNotificationBodySelector.timeBucket(forReminderTime: morning, calendar: calendar),
            .morning
        )
        let afternoon = date(hour: 14)
        XCTAssertEqual(
            ReminderNotificationBodySelector.timeBucket(forReminderTime: afternoon, calendar: calendar),
            .afternoon
        )
        let evening = date(hour: 19)
        XCTAssertEqual(
            ReminderNotificationBodySelector.timeBucket(forReminderTime: evening, calendar: calendar),
            .evening
        )
        let lateNight = date(hour: 3)
        XCTAssertEqual(
            ReminderNotificationBodySelector.timeBucket(forReminderTime: lateNight, calendar: calendar),
            .evening
        )
    }

    func test_streakBucket_lengths() {
        XCTAssertEqual(ReminderNotificationBodySelector.streakBucketBasic(streakLength: 0), .none)
        XCTAssertEqual(ReminderNotificationBodySelector.streakBucketBasic(streakLength: 1), .some)
        XCTAssertEqual(ReminderNotificationBodySelector.streakBucketBasic(streakLength: 6), .some)
        XCTAssertEqual(ReminderNotificationBodySelector.streakBucketBasic(streakLength: 7), .steady)
    }

    func test_isLapse_gapDays() {
        XCTAssertFalse(ReminderNotificationBodySelector.isLapse(gapDays: nil))
        XCTAssertFalse(ReminderNotificationBodySelector.isLapse(gapDays: 0))
        XCTAssertFalse(ReminderNotificationBodySelector.isLapse(gapDays: 2))
        XCTAssertTrue(ReminderNotificationBodySelector.isLapse(gapDays: 3))
        XCTAssertTrue(ReminderNotificationBodySelector.isLapse(gapDays: 10))
    }

    func test_localizationKey_lapse_ignoresCompletionAndStreak() {
        let key = ReminderNotificationBodySelector.localizationKey(
            isLapse: true,
            completion: .complete,
            timeBucket: .morning,
            streakBucket: .steady
        )
        XCTAssertEqual(key, "notifications.reminder.body.lapse.morning")
    }

    func test_localizationKey_notLapse_mapsMatrix() {
        let key = ReminderNotificationBodySelector.localizationKey(
            isLapse: false,
            completion: .inProgress,
            timeBucket: .afternoon,
            streakBucket: .some
        )
        XCTAssertEqual(key, "notifications.reminder.body.inProgress.afternoon.some")
    }

    func test_completionFamily_nilEntry_isEmpty() {
        XCTAssertEqual(ReminderNotificationBodySelector.completionFamily(for: nil), .empty)
    }

    func test_completionFamily_bloom() {
        let journal = Journal(
            entryDate: Date(),
            gratitudes: Entry.fiveSampleItems,
            needs: Entry.fiveSampleItems,
            people: Entry.fiveSampleItems
        )
        XCTAssertEqual(ReminderNotificationBodySelector.completionFamily(for: journal), .complete)
    }

    func test_completionFamily_notesOnly_isInProgress() {
        let journal = Journal(entryDate: Date(), readingNotes: "Notes")
        XCTAssertEqual(ReminderNotificationBodySelector.completionFamily(for: journal), .inProgress)
    }

    func test_calendarDayGapSinceLastMeaningfulEntry_nilWhenNever() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        let gap = ReminderNotificationBodySelector.calendarDayGapSinceLastMeaningfulEntry(
            entries: [],
            todayStart: today,
            calendar: calendar
        )
        XCTAssertNil(gap)
    }

    func test_calendarDayGapSinceLastMeaningfulEntry_countsFromLastDay() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        let oldDay = calendar.date(from: DateComponents(year: 2026, month: 4, day: 4))!
        let old = Journal(entryDate: oldDay, readingNotes: "Hi")
        let gap = ReminderNotificationBodySelector.calendarDayGapSinceLastMeaningfulEntry(
            entries: [old],
            todayStart: today,
            calendar: calendar
        )
        XCTAssertEqual(gap, 6)
    }

    private func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: hour, minute: 0))!
    }
}

private extension Entry {
    static var fiveSampleItems: [Entry] {
        (0..<5).map { _ in Entry(fullText: "x") }
    }
}
