import Foundation
import SwiftData

enum HistoryEntryGrouping {
    static func groupedByMonth(
        entries: [Journal],
        calendar: Calendar
    ) -> [(key: Date, entries: [Journal])] {
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            let components = calendar.dateComponents([.year, .month], from: entry.entryDate)
            return calendar.date(from: components) ?? entry.entryDate
        }
        return grouped.keys.sorted(by: >).map { month in
            let groupedEntries = grouped[month] ?? []
            return (month, groupedEntries)
        }
    }
}
