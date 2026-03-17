import XCTest
import UserNotifications
@testable import FiveCubedMoments

final class ReminderSchedulerTests: XCTestCase {
    func test_syncDailyReminder_disabled_removesPendingRequest() async {
        let center = MockUserNotificationCenter()
        let scheduler = ReminderScheduler(notificationCenter: center)

        await scheduler.syncDailyReminder(enabled: false, time: Date())

        XCTAssertEqual(center.removedIdentifiers, [ReminderSettings.notificationIdentifier])
        XCTAssertNil(center.lastAddedRequest)
    }

    func test_syncDailyReminder_deniedAuthorization_doesNotSchedule() async {
        let center = MockUserNotificationCenter(status: .denied)
        let scheduler = ReminderScheduler(notificationCenter: center)

        await scheduler.syncDailyReminder(enabled: true, time: Date())

        XCTAssertNil(center.lastAddedRequest)
        XCTAssertEqual(center.removedIdentifiers, [ReminderSettings.notificationIdentifier])
        XCTAssertFalse(center.didRequestAuthorization)
    }

    func test_syncDailyReminder_authorized_schedulesSingleDailyRequest() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let center = MockUserNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(notificationCenter: center, calendar: calendar)
        let reminderTime = date(year: 2026, month: 3, day: 17, hour: 19, minute: 45, calendar: calendar)

        await scheduler.syncDailyReminder(enabled: true, time: reminderTime)

        let request = try? XCTUnwrap(center.lastAddedRequest)
        XCTAssertEqual(request?.identifier, ReminderSettings.notificationIdentifier)
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.dateComponents.hour, 19)
        XCTAssertEqual(trigger?.dateComponents.minute, 45)
        XCTAssertTrue(trigger?.repeats ?? false)
    }

    func test_syncDailyReminder_notDetermined_requestsAuthorizationThenSchedules() async {
        let center = MockUserNotificationCenter(status: .notDetermined, shouldGrantRequestAuthorization: true)
        let scheduler = ReminderScheduler(notificationCenter: center)

        await scheduler.syncDailyReminder(enabled: true, time: Date())

        XCTAssertTrue(center.didRequestAuthorization)
        XCTAssertNotNil(center.lastAddedRequest)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}

private final class MockUserNotificationCenter: UserNotificationCenterClient {
    private let status: UNAuthorizationStatus
    private let shouldGrantRequestAuthorization: Bool

    private(set) var didRequestAuthorization = false
    private(set) var removedIdentifiers: [String]?
    private(set) var lastAddedRequest: UNNotificationRequest?

    init(
        status: UNAuthorizationStatus = .authorized,
        shouldGrantRequestAuthorization: Bool = false
    ) {
        self.status = status
        self.shouldGrantRequestAuthorization = shouldGrantRequestAuthorization
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        didRequestAuthorization = true
        return shouldGrantRequestAuthorization
    }

    func add(_ request: UNNotificationRequest) async throws {
        lastAddedRequest = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers = identifiers
    }
}
