import SwiftUI
import SwiftData

struct HistoryScreen: View {
    @Query(sort: \JournalEntry.entryDate, order: .reverse) private var entries: [JournalEntry]
    @State private var reviewInsights: ReviewInsights?
    @State private var isLoadingInsights = false

    private let calendar = Calendar.current
    private let reviewInsightsProvider = ReviewInsightsProvider.shared

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
        .navigationTitle("Review")
        .background(AppTheme.background)
        .onAppear {
            PerformanceTrace.instant("HistoryScreen.onAppear")
        }
        .task(id: entries.map(\.id)) {
            await refreshReviewInsights()
        }
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
            Section {
                ReviewSummaryCard(insights: reviewInsights, isLoading: isLoadingInsights)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(AppTheme.background)
            }

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

    @MainActor
    private func refreshReviewInsights() async {
        isLoadingInsights = true
        reviewInsights = await reviewInsightsProvider.generateInsights(
            from: entries,
            referenceDate: Date(),
            calendar: calendar
        )
        isLoadingInsights = false
    }

    private func monthYearString(from date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
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

private struct ReviewSummaryCard: View {
    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            if isLoading, insights == nil {
                ProgressView()
                    .tint(AppTheme.accent)
            } else if let insights {
                if let narrativeSummary = insights.narrativeSummary, !narrativeSummary.isEmpty {
                    Text(narrativeSummary)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                ReviewThemeRow(title: "Recurring Gratitudes", items: insights.recurringGratitudes)
                ReviewThemeRow(title: "Recurring Needs", items: insights.recurringNeeds)
                ReviewThemeRow(title: "People in Mind", items: insights.recurringPeople)

                Text(insights.resurfacingMessage)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue with")
                        .font(AppTheme.warmPaperBody.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(insights.continuityPrompt)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            } else {
                Text("Start writing this week to unlock review insights.")
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(16)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ReviewThemeRow: View {
    let title: String
    let items: [ReviewInsightTheme]

    private var itemText: String {
        guard !items.isEmpty else {
            return "No recurring patterns yet"
        }
        return items.map { "\($0.label) (\($0.count))" }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(itemText)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
        }
    }
}
