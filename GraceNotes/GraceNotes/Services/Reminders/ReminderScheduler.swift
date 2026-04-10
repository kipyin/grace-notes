import Foundation
import UserNotifications

enum ReminderSyncResult: Equatable {
    case scheduled
    case disabled
    case permissionDenied
    case failed
}

enum ReminderLiveStatus: Equatable {
    case enabled
    case off
    case notDetermined
    case denied
    case unavailable
}

protocol ReminderScheduling {
    func currentReminderStatus() async -> ReminderLiveStatus
    func enableDailyReminder(at time: Date, body: String) async -> ReminderSyncResult
    func disableDailyReminder() async -> ReminderSyncResult
    func rescheduleEnabledReminder(at time: Date, body: String) async -> ReminderSyncResult
}

protocol UserNotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func pendingReminderRequestIdentifiers() async -> [String]
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }

    func pendingReminderRequestIdentifiers() async -> [String] {
        let requests = await pendingNotificationRequests()
        return requests.map(\.identifier)
    }
}

struct ReminderScheduler {
    private let notificationCenter: UserNotificationCenterClient
    private let calendar: Calendar

    init(
        notificationCenter: UserNotificationCenterClient = UNUserNotificationCenter.current(),
        calendar: Calendar = .current
    ) {
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    func currentReminderStatus() async -> ReminderLiveStatus {
        let authorizationStatus = await notificationCenter.authorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            let identifiers = await notificationCenter.pendingReminderRequestIdentifiers()
            return identifiers.contains(ReminderSettings.notificationIdentifier) ? .enabled : .off
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .unavailable
        }
    }

    func enableDailyReminder(at time: Date, body: String) async -> ReminderSyncResult {
        switch await notificationPermissionOutcome(allowPermissionPrompt: true) {
        case .granted:
            let wasScheduled = await scheduleReminder(at: time, body: body)
            return wasScheduled ? .scheduled : .failed
        case .denied:
            removeReminder()
            return .permissionDenied
        case .failed:
            removeReminder()
            return .failed
        }
    }

    func disableDailyReminder() async -> ReminderSyncResult {
        removeReminder()
        return .disabled
    }

    /// Reschedules only when authorization is already available.
    func rescheduleEnabledReminder(at time: Date, body: String) async -> ReminderSyncResult {
        switch await notificationPermissionOutcome(allowPermissionPrompt: false) {
        case .granted:
            let wasScheduled = await scheduleReminder(at: time, body: body)
            return wasScheduled ? .scheduled : .failed
        case .denied:
            removeReminder()
            return .permissionDenied
        case .failed:
            removeReminder()
            return .failed
        }
    }

    func syncDailyReminder(enabled: Bool, time: Date, body: String) async -> ReminderSyncResult {
        if !enabled {
            return await disableDailyReminder()
        }

        return await enableDailyReminder(at: time, body: body)
    }

    private func notificationPermissionOutcome(
        allowPermissionPrompt: Bool
    ) async -> NotificationPermissionOutcome {
        let status = await notificationCenter.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .notDetermined:
            guard allowPermissionPrompt else {
                return .denied
            }
            do {
                let isAuthorized = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
                return isAuthorized ? .granted : .denied
            } catch {
                return .failed
            }
        case .denied:
            return .denied
        @unknown default:
            return .failed
        }
    }

    private func scheduleReminder(at time: Date, body: String) async -> Bool {
        removeReminder()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "app.name")
        content.body = body
        content.sound = .default

        let timeComponents = ReminderSettings.timeComponents(from: time, calendar: calendar)
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: ReminderSettings.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            return false
        }
    }

    private func removeReminder() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [ReminderSettings.notificationIdentifier]
        )
    }
}

extension ReminderScheduler: ReminderScheduling {}

private enum NotificationPermissionOutcome {
    case granted
    case denied
    case failed
}
