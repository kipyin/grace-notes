import Foundation
import UserNotifications

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

    func syncDailyReminder(enabled: Bool, time: Date) async {
        if !enabled {
            removeReminder()
            return
        }

        guard await hasNotificationPermission() else {
            removeReminder()
            return
        }

        await scheduleReminder(at: time)
    }

    private func hasNotificationPermission() async -> Bool {
        let status = await notificationCenter.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func scheduleReminder(at time: Date) async {
        removeReminder()

        let content = UNMutableNotificationContent()
        content.title = "Five Cubed Moments"
        content.body = "Take a moment to complete today's 5³."
        content.sound = .default

        let timeComponents = ReminderSettings.timeComponents(from: time, calendar: calendar)
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: ReminderSettings.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        try? await notificationCenter.add(request)
    }

    private func removeReminder() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [ReminderSettings.notificationIdentifier]
        )
    }
}
