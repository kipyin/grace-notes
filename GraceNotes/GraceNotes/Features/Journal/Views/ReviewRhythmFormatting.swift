import Foundation

/// Shared formatting for the Review reflection rhythm chart (labels, asset catalog image names). Kept small for tests.
enum ReviewRhythmFormatting {
    static func dayLabel(
        date: Date,
        displayInterval: Range<Date>,
        calendar cal: Calendar,
        referenceNow: Date
    ) -> String {
        let dayStart = cal.startOfDay(for: date)
        if displayInterval.contains(dayStart), cal.isDate(dayStart, inSameDayAs: referenceNow) {
            return String(localized: "Today")
        }
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = cal.locale ?? .current
        formatter.timeZone = cal.timeZone
        if displayInterval.contains(dayStart) {
            formatter.setLocalizedDateFormatFromTemplate("EEE")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("Md")
        }
        return formatter.string(from: dayStart)
    }

    /// Asset catalog image names for rhythm column pills (`soil` … `bloom`).
    static func assetName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            "soil"
        case .sprout:
            "sprout"
        case .twig:
            "twig"
        case .leaf:
            "leaf"
        case .bloom:
            "bloom"
        }
    }
}
