import Foundation

enum HistoryEntryGrouping {
    static func groupedByMonth(
        entries: [Journal],
        calendar: Calendar
    ) -> [(key: Date, entries: [Journal])] {
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            monthKey(for: entry.entryDate, calendar: calendar)
        }
        return grouped.keys.sorted(by: >).map { month in
            let groupedEntries = (grouped[month] ?? []).sorted {
                if $0.entryDate != $1.entryDate {
                    return $0.entryDate > $1.entryDate
                }
                return $0.id < $1.id
            }
            return (month, groupedEntries)
        }
    }

    /// Start of the calendar month containing `date`. Used so a failed `date(from:)`
    /// does not fall back to the raw entry timestamp (which would split one month into many buckets).
    private static func monthKey(for date: Date, calendar: Calendar) -> Date {
        if let intervalStart = calendar.dateInterval(of: .month, for: date)?.start {
            return intervalStart
        }
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        if let normalized = calendar.date(from: components) {
            return normalized
        }
        return gregorianUTCMonthStart(for: date)
    }

    /// When the active calendar cannot form a month start, anchor by Gregorian UTC year/month
    /// so entries in the same month are not split by day. If direct month normalization fails
    /// but year and month are known, derive the month from January 1; only then fall back to
    /// `startOfDay(for:)` (which can still split one month across buckets when all else fails).
    private static func gregorianUTCMonthStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)
            ?? TimeZone(identifier: "UTC")
            ?? TimeZone(abbreviation: "GMT")
            ?? .current
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        if let normalized = calendar.date(from: components) {
            return normalized
        }
        guard let year = components.year, let month = components.month else {
            return calendar.startOfDay(for: date)
        }
        let clampedMonth = min(max(month, 1), 12)
        var yearStartComponents = DateComponents()
        yearStartComponents.timeZone = calendar.timeZone
        yearStartComponents.year = year
        yearStartComponents.month = 1
        yearStartComponents.day = 1
        yearStartComponents.hour = 0
        yearStartComponents.minute = 0
        yearStartComponents.second = 0
        yearStartComponents.nanosecond = 0
        guard let januaryFirst = calendar.date(from: yearStartComponents) else {
            return calendar.startOfDay(for: date)
        }
        return calendar.date(byAdding: .month, value: clampedMonth - 1, to: januaryFirst)
            ?? calendar.startOfDay(for: date)
    }
}
