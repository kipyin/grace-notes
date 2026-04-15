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

    /// Reads the saved clock time. `UserDefaults` is untyped; accept `NSNumber` and reject non-finite values.
    private static func storedReminderTimeInterval(from userDefaults: UserDefaults) -> TimeInterval {
        guard let raw = userDefaults.object(forKey: ReminderSettings.timeIntervalKey) else {
            return ReminderSettings.defaultTimeInterval
        }

        let interval: TimeInterval
        if let number = raw as? NSNumber {
            interval = number.doubleValue
        } else if let value = raw as? TimeInterval {
            interval = value
        } else {
            return ReminderSettings.defaultTimeInterval
        }

        if !interval.isFinite {
            return ReminderSettings.defaultTimeInterval
        }
        return interval
    }
}
