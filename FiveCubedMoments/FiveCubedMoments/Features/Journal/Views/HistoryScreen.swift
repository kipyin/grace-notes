import SwiftUI
import SwiftData

struct HistoryScreen: View {
    @Query(sort: \JournalEntry.entryDate, order: .reverse) private var entries: [JournalEntry]

    private let calendar = Calendar.current
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private var groupedEntries: [(key: Date, entries: [JournalEntry])] {
        HistoryEntryGrouping.groupedByMonth(entries: entries, calendar: calendar)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .background(AppTheme.background)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No entries yet", systemImage: "doc.text")
        } description: {
            Text("Start with today.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyList: some View {
        List {
            ForEach(groupedEntries, id: \.key) { group in
                Section {
                    ForEach(group.entries, id: \.id) { entry in
                        NavigationLink {
                            JournalScreen(entryDate: entry.entryDate)
                        } label: {
                            HistoryRow(entry: entry)
                        }
                        .listRowBackground(AppTheme.paper)
                    }
                } header: {
                    Text(monthYearString(from: group.key))
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }

    private func monthYearString(from date: Date) -> String {
        Self.monthYearFormatter.string(from: date)
    }
}

enum HistoryEntryGrouping {
    static func groupedByMonth(
        entries: [JournalEntry],
        calendar: Calendar
    ) -> [(key: Date, entries: [JournalEntry])] {
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

private struct HistoryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack {
            Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if entry.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.complete)
                    .font(.caption)
            }
        }
    }
}
