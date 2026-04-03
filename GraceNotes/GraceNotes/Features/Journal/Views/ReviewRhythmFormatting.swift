import Foundation

/// Shared formatting for the Review reflection rhythm chart (labels, asset catalog image names). Kept small for tests.
enum ReviewRhythmFormatting {
    /// Local seven calendar days ending on ``referenceNow`` (inclusive): `[referenceNow − 6 … referenceNow]`.
    static func isLocalDayInPastSevenCalendarDaysEndingReference(
        dayStart: Date,
        referenceNow: Date,
        calendar: Calendar
    ) -> Bool {
        let ref = calendar.startOfDay(for: referenceNow)
        guard let oldest = calendar.date(byAdding: .day, value: -6, to: ref),
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: ref)
        else {
            return false
        }
        let windowStartNormalized = calendar.startOfDay(for: oldest)
        let normalized = calendar.startOfDay(for: dayStart)
        return normalized >= windowStartNormalized && normalized < endExclusive
    }

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
        if Self.isLocalDayInPastSevenCalendarDaysEndingReference(
            dayStart: dayStart,
            referenceNow: referenceNow,
            calendar: cal
        ) {
            let formatter = DateFormatter()
            formatter.calendar = cal
            formatter.locale = cal.locale ?? .current
            formatter.timeZone = cal.timeZone
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            return formatter.string(from: dayStart)
        }
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = cal.locale ?? .current
        formatter.timeZone = cal.timeZone
        formatter.setLocalizedDateFormatFromTemplate("Md")
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
