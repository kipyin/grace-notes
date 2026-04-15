import Foundation

struct ReminderSettings {
    static let timeIntervalKey = "dailyReminderTimeInterval"
    static let notificationIdentifier = "dailyJournalReminder"

    static var defaultTimeInterval: TimeInterval {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let date = calendar.date(from: components) ?? Date()
        return date.timeIntervalSinceReferenceDate
    }

    /// Interprets an optional stored `TimeInterval`, falling back to ``defaultTimeInterval`` when the value is
    /// missing or non-finite.
    static func sanitizedTimeInterval(stored: TimeInterval?) -> TimeInterval {
        let base = stored ?? defaultTimeInterval
        return base.isFinite ? base : defaultTimeInterval
    }

    /// Loads ``timeIntervalKey`` from `userDefaults`, applies ``sanitizedTimeInterval(stored:)``, and persists when
    /// the stored value was present but non-finite.
    static func coercedTimeInterval(fromUserDefaults userDefaults: UserDefaults) -> TimeInterval {
        let stored = userDefaults.object(forKey: timeIntervalKey) as? TimeInterval
        let interval = sanitizedTimeInterval(stored: stored)
        if let stored, !stored.isFinite {
            userDefaults.set(interval, forKey: timeIntervalKey)
        }
        return interval
    }

    static func date(from storedTimeInterval: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: storedTimeInterval)
    }

    static func timeComponents(
        from date: Date,
        calendar: Calendar = .current
    ) -> DateComponents {
        calendar.dateComponents([.hour, .minute], from: date)
    }
}
