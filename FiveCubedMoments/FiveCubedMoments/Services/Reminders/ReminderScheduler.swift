import Foundation
import UserNotifications

enum ReminderSyncResult: Equatable {
    case scheduled
    case disabled
    case permissionDenied
    case failed
}

protocol UserNotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
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

    func syncDailyReminder(enabled: Bool, time: Date) async -> ReminderSyncResult {
        if !enabled {
            removeReminder()
            return .disabled
        }

        switch await notificationPermissionOutcome() {
        case .granted:
            let wasScheduled = await scheduleReminder(at: time)
            return wasScheduled ? .scheduled : .failed
        case .denied:
            removeReminder()
            return .permissionDenied
        case .failed:
            removeReminder()
            return .failed
        }
    }

    private func notificationPermissionOutcome() async -> NotificationPermissionOutcome {
        let status = await notificationCenter.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .notDetermined:
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

    private func scheduleReminder(at time: Date) async -> Bool {
        removeReminder()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Five Cubed Moments")
        content.body = String(localized: "Take a moment to complete today's 5³.")
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

private enum NotificationPermissionOutcome {
    case granted
    case denied
    case failed
}
