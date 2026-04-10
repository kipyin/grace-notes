import XCTest
@testable import GraceNotes

@MainActor
final class ReminderSettingsFlowModelTests: XCTestCase {
    func test_enableReminders_permissionDenied_setsDeniedState() async {
        let scheduler = MockReminderScheduling()
        scheduler.enableResult = .permissionDenied
        let userDefaults = makeUserDefaults()
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: userDefaults)
        model.reminderNotificationBody = { _ in "body" }

        await model.enableReminders()

        XCTAssertEqual(model.liveStatus, .denied)
        XCTAssertFalse(model.isReminderEnabled)
    }

    func test_enableReminders_success_persistsSelectedTime() async {
        let scheduler = MockReminderScheduling()
        scheduler.enableResult = .scheduled
        scheduler.currentStatus = .enabled
        let userDefaults = makeUserDefaults()
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: userDefaults)
        let selectedTime = Date(timeIntervalSinceReferenceDate: 321_123)
        model.selectedTime = selectedTime
        model.reminderNotificationBody = { _ in "body" }

        await model.enableReminders()

        XCTAssertEqual(model.liveStatus, .enabled)
        let storedTime = userDefaults.object(forKey: ReminderSettings.timeIntervalKey) as? TimeInterval
        XCTAssertEqual(storedTime, selectedTime.timeIntervalSinceReferenceDate)
    }

    func test_refreshStatus_reflectsSystemChangeFromDeniedToEnabled() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .denied
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())

        await model.refreshStatus()
        XCTAssertEqual(model.liveStatus, .denied)

        scheduler.currentStatus = .enabled
        await model.refreshStatus()
        XCTAssertEqual(model.liveStatus, .enabled)
    }

    func test_saveEnabledReminderTime_permissionDenied_setsErrorAndDenied() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .enabled
        scheduler.rescheduleResult = .permissionDenied
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        await model.saveEnabledReminderTime()

        XCTAssertEqual(model.liveStatus, .denied)
        XCTAssertNotNil(model.transientErrorMessage)
    }

    func test_disableReminders_setsOffState() async {
        let scheduler = MockReminderScheduling()
        scheduler.disableResult = .disabled
        scheduler.currentStatus = .off
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())

        await model.disableReminders()

        XCTAssertEqual(model.liveStatus, .off)
    }

    func test_handleSelectedTimeChanged_enabled_implicitlyReschedules() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .enabled
        scheduler.rescheduleResult = .scheduled
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        model.selectedTime = Date(timeIntervalSinceReferenceDate: 911_000)
        model.handleSelectedTimeChanged()
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(scheduler.rescheduleCallCount, 1)
    }

    func test_handleSelectedTimeChanged_rapidUpdates_coalescesToOneReschedule() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .enabled
        scheduler.rescheduleResult = .scheduled
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        model.selectedTime = Date(timeIntervalSinceReferenceDate: 100_000)
        model.handleSelectedTimeChanged()
        model.selectedTime = Date(timeIntervalSinceReferenceDate: 100_060)
        model.handleSelectedTimeChanged()
        model.selectedTime = Date(timeIntervalSinceReferenceDate: 100_120)
        model.handleSelectedTimeChanged()
        try? await Task.sleep(nanoseconds: 750_000_000)

        XCTAssertEqual(scheduler.rescheduleCallCount, 1)
    }

    func test_handleSelectedTimeChanged_offState_doesNotReschedule() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .off
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        model.selectedTime = Date(timeIntervalSinceReferenceDate: 456_000)
        model.handleSelectedTimeChanged()
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(scheduler.rescheduleCallCount, 0)
    }

    func test_refreshStatus_isPassiveAndDoesNotEnablePermissionPrompt() async {
        let scheduler = MockReminderScheduling()
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())

        await model.refreshStatus()

        XCTAssertEqual(scheduler.enableCallCount, 0)
        XCTAssertEqual(scheduler.rescheduleCallCount, 0)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "ReminderSettingsFlowModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class MockReminderScheduling: ReminderScheduling {
    var currentStatus: ReminderLiveStatus = .off
    var enableResult: ReminderSyncResult = .scheduled
    var disableResult: ReminderSyncResult = .disabled
    var rescheduleResult: ReminderSyncResult = .scheduled

    private(set) var enableCallCount = 0
    private(set) var rescheduleCallCount = 0

    func currentReminderStatus() async -> ReminderLiveStatus {
        currentStatus
    }

    func enableDailyReminder(at time: Date, body: String) async -> ReminderSyncResult {
        enableCallCount += 1
        _ = body
        return enableResult
    }

    func disableDailyReminder() async -> ReminderSyncResult {
        disableResult
    }

    func rescheduleEnabledReminder(at time: Date, body: String) async -> ReminderSyncResult {
        rescheduleCallCount += 1
        _ = body
        return rescheduleResult
    }
}
