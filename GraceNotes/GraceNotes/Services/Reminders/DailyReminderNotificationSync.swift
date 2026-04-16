import Foundation
import SwiftData

/// Refreshes the pending repeating reminder so its body matches current journal context.
enum DailyReminderNotificationSync {
    @MainActor
    static func rescheduleEnabledReminderIfNeeded(
        modelContext: ModelContext,
        reminderScheduler: any ReminderScheduling = ReminderScheduler(),
        userDefaults: UserDefaults = .standard,
        now: Date = Date()
    ) async {
        let status = await reminderScheduler.currentReminderStatus()
        guard status == .enabled else { return }

        let interval = ReminderSettings.coercedTimeInterval(fromUserDefaults: userDefaults)
        let reminderTime = ReminderSettings.date(from: interval)
        let body: String
        do {
            body = try ReminderNotificationBodyBuilder.localizedBody(
                modelContext: modelContext,
                reminderTime: reminderTime,
                now: now
            )
        } catch {
            body = String(localized: String.LocalizationValue("notifications.reminder.body.fallback"))
        }
        _ = await reminderScheduler.rescheduleEnabledReminder(at: reminderTime, body: body)
    }
}
