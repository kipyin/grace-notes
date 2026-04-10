import XCTest
import UserNotifications
@testable import GraceNotes

final class ReminderSchedulerTests: XCTestCase {
    func test_currentReminderStatus_authorizedWithPendingRequest_returnsEnabled() async {
        let center = MockUserNotificationCenter(
            status: .authorized,
            pendingIdentifiers: [ReminderSettings.notificationIdentifier]
        )
        let scheduler = ReminderScheduler(notificationCenter: center)

        let status = await scheduler.currentReminderStatus()

        XCTAssertEqual(status, .enabled)
        XCTAssertFalse(center.didRequestAuthorization)
    }

    func test_currentReminderStatus_authorizedWithoutPendingRequest_returnsOff() async {
        let center = MockUserNotificationCenter(status: .authorized, pendingIdentifiers: [])
        let scheduler = ReminderScheduler(notificationCenter: center)

        let status = await scheduler.currentReminderStatus()

        XCTAssertEqual(status, .off)
        XCTAssertFalse(center.didRequestAuthorization)
    }

    func test_currentReminderStatus_notDetermined_returnsNotDeterminedWithoutPrompt() async {
        let center = MockUserNotificationCenter(status: .notDetermined, pendingIdentifiers: [])
        let scheduler = ReminderScheduler(notificationCenter: center)

        let status = await scheduler.currentReminderStatus()

        XCTAssertEqual(status, .notDetermined)
        XCTAssertFalse(center.didRequestAuthorization)
    }

    func test_currentReminderStatus_denied_returnsDeniedWithoutPrompt() async {
        let center = MockUserNotificationCenter(status: .denied, pendingIdentifiers: [])
        let scheduler = ReminderScheduler(notificationCenter: center)

        let status = await scheduler.currentReminderStatus()

        XCTAssertEqual(status, .denied)
        XCTAssertFalse(center.didRequestAuthorization)
    }

    func test_syncDailyReminder_disabled_removesPendingRequest() async {
        let center = MockUserNotificationCenter()
        let scheduler = ReminderScheduler(notificationCenter: center)

        let result = await scheduler.syncDailyReminder(enabled: false, time: Date(), body: "x")

        XCTAssertEqual(result, .disabled)
        XCTAssertEqual(center.removedIdentifiers, [ReminderSettings.notificationIdentifier])
        XCTAssertNil(center.lastAddedRequest)
    }

    func test_syncDailyReminder_deniedAuthorization_doesNotSchedule() async {
        let center = MockUserNotificationCenter(status: .denied)
        let scheduler = ReminderScheduler(notificationCenter: center)

        let result = await scheduler.syncDailyReminder(enabled: true, time: Date(), body: "Body A")

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertNil(center.lastAddedRequest)
        XCTAssertEqual(center.removedIdentifiers, [ReminderSettings.notificationIdentifier])
        XCTAssertFalse(center.didRequestAuthorization)
    }

    func test_syncDailyReminder_authorized_schedulesSingleDailyRequest() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let center = MockUserNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(notificationCenter: center, calendar: calendar)
        let reminderTime = date(
            components: DateComponents(year: 2026, month: 3, day: 17, hour: 19, minute: 45),
            calendar: calendar
        )

        let result = await scheduler.syncDailyReminder(enabled: true, time: reminderTime, body: "Evening prompt")

        XCTAssertEqual(result, .scheduled)
        let request = try? XCTUnwrap(center.lastAddedRequest)
        XCTAssertEqual(request?.identifier, ReminderSettings.notificationIdentifier)
        XCTAssertEqual(request?.content.body, "Evening prompt")
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.dateComponents.hour, 19)
        XCTAssertEqual(trigger?.dateComponents.minute, 45)
        XCTAssertTrue(trigger?.repeats ?? false)
    }

    func test_syncDailyReminder_notDetermined_requestsAuthorizationThenSchedules() async {
        let center = MockUserNotificationCenter(status: .notDetermined, shouldGrantRequestAuthorization: true)
        let scheduler = ReminderScheduler(notificationCenter: center)

        let result = await scheduler.syncDailyReminder(enabled: true, time: Date(), body: "Body A")

        XCTAssertEqual(result, .scheduled)
        XCTAssertTrue(center.didRequestAuthorization)
        XCTAssertNotNil(center.lastAddedRequest)
    }

    func test_rescheduleEnabledReminder_notDetermined_doesNotPromptAndReturnsDenied() async {
        let center = MockUserNotificationCenter(status: .notDetermined, shouldGrantRequestAuthorization: true)
        let scheduler = ReminderScheduler(notificationCenter: center)

        let result = await scheduler.rescheduleEnabledReminder(at: Date(), body: "x")

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertFalse(center.didRequestAuthorization)
        XCTAssertNil(center.lastAddedRequest)
    }

    func test_disableDailyReminder_removesPendingRequest() async {
        let center = MockUserNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(notificationCenter: center)

        let result = await scheduler.disableDailyReminder()

        XCTAssertEqual(result, .disabled)
        XCTAssertEqual(center.removedIdentifiers, [ReminderSettings.notificationIdentifier])
    }

    func test_syncDailyReminder_addFailure_returnsFailedAndDoesNotPersistRequest() async {
        let center = MockUserNotificationCenter(status: .authorized, shouldFailAdd: true)
        let scheduler = ReminderScheduler(notificationCenter: center)

        let result = await scheduler.syncDailyReminder(enabled: true, time: Date(), body: "Body A")

        XCTAssertEqual(result, .failed)
        XCTAssertNil(center.lastAddedRequest)
        XCTAssertEqual(center.removedIdentifiers, [ReminderSettings.notificationIdentifier])
    }

    private func date(components: DateComponents, calendar: Calendar) -> Date {
        var components = components
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}

private final class MockUserNotificationCenter: UserNotificationCenterClient {
    private let status: UNAuthorizationStatus
    private let pendingIdentifiers: [String]
    private let shouldGrantRequestAuthorization: Bool
    private let shouldFailAdd: Bool

    private(set) var didRequestAuthorization = false
    private(set) var removedIdentifiers: [String]?
    private(set) var lastAddedRequest: UNNotificationRequest?

    init(
        status: UNAuthorizationStatus = .authorized,
        pendingIdentifiers: [String] = [],
        shouldGrantRequestAuthorization: Bool = false,
        shouldFailAdd: Bool = false
    ) {
        self.status = status
        self.pendingIdentifiers = pendingIdentifiers
        self.shouldGrantRequestAuthorization = shouldGrantRequestAuthorization
        self.shouldFailAdd = shouldFailAdd
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func pendingReminderRequestIdentifiers() async -> [String] {
        pendingIdentifiers
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        didRequestAuthorization = true
        return shouldGrantRequestAuthorization
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldFailAdd {
            throw MockNotificationError.addFailed
        }
        lastAddedRequest = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers = identifiers
    }
}

private enum MockNotificationError: Error {
    case addFailed
}
