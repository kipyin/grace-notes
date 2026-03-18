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
