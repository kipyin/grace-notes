import SwiftData
import XCTest
@testable import GraceNotes

@MainActor
final class DailyReminderNotificationSyncTests: XCTestCase {
    func test_rescheduleEnabledReminderIfNeeded_nonFiniteStoredTime_schedulesDefaultReminderTime() async throws {
        let scheduler = DailyReminderSyncSchedulerMock()
        scheduler.currentStatus = .enabled

        let suiteName = "DailyReminderNotificationSyncTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults.set(Double.nan, forKey: ReminderSettings.timeIntervalKey)

        let context = try SwiftDataTestIsolation.makeModelContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        await DailyReminderNotificationSync.rescheduleEnabledReminderIfNeeded(
            modelContext: context,
            reminderScheduler: scheduler,
            userDefaults: userDefaults,
            now: now
        )

        let expectedInterval = ReminderSettings.defaultTimeInterval
        XCTAssertEqual(
            userDefaults.object(forKey: ReminderSettings.timeIntervalKey) as? TimeInterval,
            expectedInterval
        )
        XCTAssertEqual(scheduler.rescheduleCallCount, 1)
        let captured = try XCTUnwrap(scheduler.lastRescheduleTime)
        XCTAssertEqual(captured.timeIntervalSinceReferenceDate, expectedInterval, accuracy: 0.001)
    }

    func test_rescheduleEnabledReminderIfNeeded_remindersOff_doesNotReschedule() async throws {
        let scheduler = DailyReminderSyncSchedulerMock()
        scheduler.currentStatus = .off

        let suiteName = "DailyReminderNotificationSyncTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults.set(Double.nan, forKey: ReminderSettings.timeIntervalKey)

        let context = try SwiftDataTestIsolation.makeModelContext()

        await DailyReminderNotificationSync.rescheduleEnabledReminderIfNeeded(
            modelContext: context,
            reminderScheduler: scheduler,
            userDefaults: userDefaults
        )

        XCTAssertEqual(scheduler.rescheduleCallCount, 0)
    }
}

@MainActor
private final class DailyReminderSyncSchedulerMock: ReminderScheduling {
    var currentStatus: ReminderLiveStatus = .off
    private(set) var rescheduleCallCount = 0
    private(set) var lastRescheduleTime: Date?

    func currentReminderStatus() async -> ReminderLiveStatus {
        currentStatus
    }

    func enableDailyReminder(at time: Date, body: String) async -> ReminderSyncResult {
        _ = time
        _ = body
        return .scheduled
    }

    func disableDailyReminder() async -> ReminderSyncResult {
        .disabled
    }

    func rescheduleEnabledReminder(at time: Date, body: String) async -> ReminderSyncResult {
        rescheduleCallCount += 1
        lastRescheduleTime = time
        _ = body
        return .scheduled
    }
}
