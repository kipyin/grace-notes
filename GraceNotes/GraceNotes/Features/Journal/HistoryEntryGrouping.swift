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
    /// so entries in the same month are not split by day. `startOfDay` is only used if even
    /// this normalization fails.
    private static func gregorianUTCMonthStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        if let normalized = calendar.date(from: components) {
            return normalized
        }
        return calendar.startOfDay(for: date)
    }
}
