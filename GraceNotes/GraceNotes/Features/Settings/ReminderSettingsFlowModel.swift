import Foundation
import Combine

@MainActor
final class ReminderSettingsFlowModel: ObservableObject {
    @Published private(set) var liveStatus: ReminderLiveStatus = .off
    @Published var selectedTime: Date
    @Published private(set) var isWorking = false
    @Published var transientErrorMessage: String?

    /// Set from a view with SwiftData access. Maps scheduled reminder clock time to the localized notification body.
    var reminderNotificationBody: ((Date) -> String)?

    private let reminderScheduler: any ReminderScheduling
    private let userDefaults: UserDefaults
    private var pendingRescheduleTask: Task<Void, Never>?
    private var pendingRescheduleAfterCurrentSave = false
    private var hasLoadedLiveStatus = false

    init(
        reminderScheduler: any ReminderScheduling = ReminderScheduler(),
        userDefaults: UserDefaults = .standard
    ) {
        self.reminderScheduler = reminderScheduler
        self.userDefaults = userDefaults
        let storedTimeInterval = userDefaults.object(forKey: ReminderSettings.timeIntervalKey) as? TimeInterval
            ?? ReminderSettings.defaultTimeInterval
        selectedTime = ReminderSettings.date(from: storedTimeInterval)
    }

    deinit {
        pendingRescheduleTask?.cancel()
    }

    var summaryText: String {
        switch liveStatus {
        case .enabled:
            return selectedTime.formatted(date: .omitted, time: .shortened)
        case .denied:
            return String(localized: "notifications.reminder.offDenied")
        case .off, .notDetermined, .unavailable:
            return String(localized: "common.off")
        }
    }

    var isReminderEnabled: Bool {
        liveStatus == .enabled
    }

    var isPermissionDenied: Bool {
        liveStatus == .denied
    }

    func refreshStatus() async {
        liveStatus = await reminderScheduler.currentReminderStatus()
        hasLoadedLiveStatus = true
    }

    func enableReminders() async {
        await runWithWorking {
            transientErrorMessage = nil
            let result = await reminderScheduler.enableDailyReminder(at: selectedTime, body: resolvedReminderBody())
            switch result {
            case .scheduled:
                persistSelectedTime()
                await refreshStatus()
            case .permissionDenied:
                liveStatus = .denied
            case .failed:
                liveStatus = .unavailable
                transientErrorMessage = String(
                    localized: "notifications.reminder.scheduleFailed"
                )
            case .disabled:
                await refreshStatus()
            }
        }
    }

    func disableReminders() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        pendingRescheduleTask?.cancel()
        pendingRescheduleAfterCurrentSave = false

        transientErrorMessage = nil
        _ = await reminderScheduler.disableDailyReminder()
        await refreshStatus()
    }

    func saveEnabledReminderTime() async {
        guard liveStatus == .enabled else { return }
        if isWorking {
            pendingRescheduleAfterCurrentSave = true
            return
        }

        isWorking = true
        defer { isWorking = false }

        while true {
            pendingRescheduleAfterCurrentSave = false
            transientErrorMessage = nil

            let body = resolvedReminderBody()
            let result = await reminderScheduler.rescheduleEnabledReminder(at: selectedTime, body: body)
            switch result {
            case .scheduled:
                persistSelectedTime()
                liveStatus = .enabled
            case .permissionDenied:
                liveStatus = .denied
                transientErrorMessage = String(
                    localized: "notifications.reminder.confirmTimeInSettings"
                )
            case .failed:
                liveStatus = .unavailable
                transientErrorMessage = String(
                    localized: "notifications.reminder.saveFailed"
                )
            case .disabled:
                liveStatus = .off
            }

            if !pendingRescheduleAfterCurrentSave || liveStatus != .enabled {
                break
            }
        }
    }

    func clearTransientError() {
        transientErrorMessage = nil
    }

    func setReminderEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            await enableReminders()
        } else {
            await disableReminders()
        }
    }

    func handleSelectedTimeChanged() {
        guard hasLoadedLiveStatus, liveStatus == .enabled else { return }
        pendingRescheduleTask?.cancel()
        pendingRescheduleTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await self?.saveEnabledReminderTime()
            } catch {
                // Ignore cancellation from rapid picker updates.
            }
        }
    }

    private func runWithWorking(_ work: () async -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        await work()
        isWorking = false
        await drainPendingRescheduleIfNeeded()
    }

    /// Runs a deferred time save after `isWorking` drops (picker updates coalesced during enable).
    private func drainPendingRescheduleIfNeeded() async {
        guard pendingRescheduleAfterCurrentSave else { return }
        pendingRescheduleAfterCurrentSave = false
        guard liveStatus == .enabled else { return }
        await saveEnabledReminderTime()
    }

    private func resolvedReminderBody() -> String {
        if let reminderNotificationBody {
            return reminderNotificationBody(selectedTime)
        }
        return String(localized: String.LocalizationValue("notifications.reminder.body.fallback"))
    }

    private func persistSelectedTime() {
        userDefaults.set(selectedTime.timeIntervalSinceReferenceDate, forKey: ReminderSettings.timeIntervalKey)
    }
}
