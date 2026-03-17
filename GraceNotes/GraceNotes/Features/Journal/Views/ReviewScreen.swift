import SwiftUI
import SwiftData

struct ReviewScreen: View {
    private enum ReviewMode: CaseIterable, Identifiable {
        case insights
        case timeline

        var id: Self { self }

        var localizedTitle: String {
            switch self {
            case .insights:
                return String(localized: "Insights")
            case .timeline:
                return String(localized: "Timeline")
            }
        }
    }

    @Query(sort: \JournalEntry.entryDate, order: .reverse) private var entries: [JournalEntry]
    @State private var reviewInsights: ReviewInsights?
    @State private var isLoadingInsights = false
    @State private var selectedMode: ReviewMode = .insights

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
        .navigationTitle(String(localized: "Review"))
        .background(AppTheme.background)
        .onAppear {
            PerformanceTrace.instant("ReviewScreen.onAppear")
        }
        .task(id: entries.map(\.updatedAt)) {
            guard selectedMode == .insights else { return }
            await refreshReviewInsights()
        }
        .onChange(of: selectedMode) { _, newMode in
            guard newMode == .insights else { return }
            Task {
                await refreshReviewInsights()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No entries yet"), systemImage: "doc.text")
        } description: {
            Text(String(localized: "Start with today."))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyList: some View {
        List {
            Section {
                Picker(String(localized: "Review mode"), selection: $selectedMode) {
                    ForEach(ReviewMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
                .listRowBackground(AppTheme.background)
            }

            switch selectedMode {
            case .insights:
                Section {
                    ReviewSummaryCard(insights: reviewInsights, isLoading: isLoadingInsights)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(AppTheme.background)
                }
            case .timeline:
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
        HStack(spacing: 8) {
            Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            completionBadge
        }
    }

    @ViewBuilder
    private var completionBadge: some View {
        switch entry.completionLevel {
        case .fullFiveCubed:
            statusChip(text: String(localized: "Full"), color: AppTheme.complete)
        case .standardReflection:
            statusChip(text: String(localized: "Standard"), color: AppTheme.accent)
        case .quickCheckIn:
            statusChip(text: String(localized: "Quick"), color: AppTheme.textMuted)
        case .none:
            EmptyView()
        }
    }

    private func statusChip(text: String, color: Color) -> some View {
        Text(text)
            .font(AppTheme.warmPaperBody.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.background)
            .clipShape(Capsule())
    }
}

private struct ReviewSummaryCard: View {
    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "This Week"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            if isLoading, insights == nil {
                ProgressView()
                    .tint(AppTheme.accent)
            } else if let insights {
                HStack {
                    Text(String(localized: "Source"))
                        .font(AppTheme.warmPaperBody.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(insightSourceText(insights.source))
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.background)
                        .clipShape(Capsule())
                    Spacer()
                }

                Text(weekRangeText(insights))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)

                if let narrativeSummary = insights.narrativeSummary, !narrativeSummary.isEmpty {
                    Text(narrativeSummary)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                ReviewThemeRow(title: String(localized: "Recurring Gratitudes"), items: insights.recurringGratitudes)
                ReviewThemeRow(title: String(localized: "Recurring Needs"), items: insights.recurringNeeds)
                ReviewThemeRow(title: String(localized: "People in Mind"), items: insights.recurringPeople)

                Text(insights.resurfacingMessage)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Continue with"))
                        .font(AppTheme.warmPaperBody.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(insights.continuityPrompt)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            } else {
                Text(String(localized: "Start writing this week to unlock review insights."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(16)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func insightSourceText(_ source: ReviewInsightSource) -> String {
        switch source {
        case .cloudAI:
            return String(localized: "AI")
        case .deterministic:
            return String(localized: "On-device")
        }
    }

    private func weekRangeText(_ insights: ReviewInsights) -> String {
        let calendar = Calendar.current
        let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: insights.weekEnd) ?? insights.weekEnd
        let startText = insights.weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = inclusiveEnd.formatted(.dateTime.month(.abbreviated).day())
        return String(
            format: String(localized: "%1$@ to %2$@"),
            startText,
            endText
        )
    }
}

private struct ReviewThemeRow: View {
    let title: String
    let items: [ReviewInsightTheme]

    private var itemText: String {
        guard !items.isEmpty else {
            return String(localized: "No recurring patterns yet")
        }
        return items.map {
            String(
                format: String(localized: "%1$@ (%2$lld)"),
                $0.label,
                $0.count
            )
        }.joined(separator: ", ")
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
