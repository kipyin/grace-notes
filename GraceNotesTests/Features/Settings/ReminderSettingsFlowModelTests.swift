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

    /// When another save is requested while a reschedule is awaiting the system, the in-flight save must run again
    /// after the first completion (and end-of-save drain must not drop a flag set during the final await).
    func test_saveEnabledReminderTime_concurrentSaveDuringRescheduleAwait_performsSecondReschedule() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .enabled
        scheduler.rescheduleResult = .scheduled
        let gate = RescheduleTestGate()
        scheduler.rescheduleAwaitHook = { await gate.waitUntilOpened() }

        let userDefaults = makeUserDefaults()
        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: userDefaults)
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        async let firstSave: Void = model.saveEnabledReminderTime()

        let deadline = Date().addingTimeInterval(2)
        while scheduler.rescheduleCallCount < 1 {
            if Date() > deadline {
                XCTFail("Timed out waiting for the first reschedule call")
                await gate.open()
                await firstSave
                return
            }
            await Task.yield()
        }

        await model.saveEnabledReminderTime()
        await gate.open()

        await firstSave

        XCTAssertEqual(scheduler.rescheduleCallCount, 2)
    }

    /// Disable while reschedule awaits the system defers until the busy window ends, then turns reminders off.
    func test_disableDuringInFlightReschedule_defersDisableUntilRescheduleCompletes() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .enabled
        scheduler.rescheduleResult = .scheduled
        scheduler.disableResult = .disabled
        let gate = RescheduleTestGate()
        scheduler.rescheduleAwaitHook = { await gate.waitUntilOpened() }

        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        async let saveTask: Void = model.saveEnabledReminderTime()

        let deadline = Date().addingTimeInterval(2)
        while scheduler.rescheduleCallCount < 1 {
            if Date() > deadline {
                XCTFail("Timed out waiting for the first reschedule call")
                await gate.open()
                await saveTask
                return
            }
            await Task.yield()
        }

        XCTAssertEqual(scheduler.disableCallCount, 0)
        await model.disableReminders()
        XCTAssertEqual(scheduler.disableCallCount, 0)

        await gate.open()
        await saveTask

        XCTAssertEqual(scheduler.disableCallCount, 1)
        XCTAssertEqual(model.liveStatus, .off)
        XCTAssertFalse(model.isWorking)
    }

    /// Toggle off during reschedule, then on before work finishes: no stale deferred disable after re-enable.
    func test_disableThenEnableDuringInFlightReschedule_doesNotApplyDeferredDisableAfterReEnable() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .enabled
        scheduler.rescheduleResult = .scheduled
        scheduler.disableResult = .disabled
        scheduler.enableResult = .scheduled
        let gate = RescheduleTestGate()
        scheduler.rescheduleAwaitHook = { await gate.waitUntilOpened() }

        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        async let saveTask: Void = model.saveEnabledReminderTime()

        let deadline = Date().addingTimeInterval(2)
        while scheduler.rescheduleCallCount < 1 {
            if Date() > deadline {
                XCTFail("Timed out waiting for the first reschedule call")
                await gate.open()
                await saveTask
                return
            }
            await Task.yield()
        }

        await model.disableReminders()
        await model.enableReminders()

        XCTAssertEqual(scheduler.disableCallCount, 0)

        await gate.open()
        await saveTask

        XCTAssertEqual(scheduler.disableCallCount, 0)
        XCTAssertEqual(scheduler.enableCallCount, 0)
        XCTAssertEqual(model.liveStatus, .enabled)
        XCTAssertFalse(model.isWorking)
    }

    /// A second disable while the first awaits must not leave coalesced pending disable stuck for a later drain.
    func test_redundantDisableDuringInFlightDisable_clearsCoalescedPending() async {
        let scheduler = MockReminderScheduling()
        scheduler.currentStatus = .enabled
        scheduler.disableResult = .disabled
        scheduler.enableResult = .scheduled
        let gate = RescheduleTestGate()
        scheduler.disableAwaitHook = { await gate.waitUntilOpened() }

        let model = ReminderSettingsFlowModel(reminderScheduler: scheduler, userDefaults: makeUserDefaults())
        model.reminderNotificationBody = { _ in "body" }
        await model.refreshStatus()

        async let firstDisable: Void = model.disableReminders()

        let deadline = Date().addingTimeInterval(2)
        while scheduler.disableCallCount < 1 {
            if Date() > deadline {
                XCTFail("Timed out waiting for the first disable call")
                await gate.open()
                await firstDisable
                return
            }
            await Task.yield()
        }

        await model.disableReminders()
        await gate.open()
        await firstDisable

        XCTAssertEqual(scheduler.disableCallCount, 1)

        await model.enableReminders()

        XCTAssertEqual(scheduler.disableCallCount, 1)
        XCTAssertEqual(scheduler.enableCallCount, 1)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "ReminderSettingsFlowModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private final class MockReminderScheduling: ReminderScheduling {
    var currentStatus: ReminderLiveStatus = .off
    var enableResult: ReminderSyncResult = .scheduled
    var disableResult: ReminderSyncResult = .disabled
    var rescheduleResult: ReminderSyncResult = .scheduled
    /// Optional hook after `rescheduleCallCount` increments, before the result is returned.
    var rescheduleAwaitHook: (() async -> Void)?
    /// Optional hook after `disableCallCount` increments, before the result is returned.
    var disableAwaitHook: (() async -> Void)?

    private(set) var enableCallCount = 0
    private(set) var rescheduleCallCount = 0
    private(set) var disableCallCount = 0

    func currentReminderStatus() async -> ReminderLiveStatus {
        currentStatus
    }

    func enableDailyReminder(at time: Date, body: String) async -> ReminderSyncResult {
        enableCallCount += 1
        _ = body
        return enableResult
    }

    func disableDailyReminder() async -> ReminderSyncResult {
        disableCallCount += 1
        if let disableAwaitHook {
            await disableAwaitHook()
        }
        currentStatus = .off
        return disableResult
    }

    func rescheduleEnabledReminder(at time: Date, body: String) async -> ReminderSyncResult {
        rescheduleCallCount += 1
        if let rescheduleAwaitHook {
            await rescheduleAwaitHook()
        }
        _ = body
        return rescheduleResult
    }
}

/// Unblocks waiters when `open()` is called (interleaves concurrent reminder save paths).
private actor RescheduleTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilOpened() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        for continuation in waiters {
            continuation.resume()
        }
        waiters.removeAll()
    }
}
