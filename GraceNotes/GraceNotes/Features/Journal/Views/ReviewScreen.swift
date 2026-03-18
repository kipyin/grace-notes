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
    @State private var lastInsightsRefreshKey: ReviewInsightsRefreshKey?
    @State private var timelineGroups: [(key: Date, entries: [JournalEntry])] = []
    @AppStorage(ReviewInsightsProvider.useAIReviewInsightsKey) private var useAIReviewInsights = false

    private let calendar = Calendar.current
    private let reviewInsightsProvider = ReviewInsightsProvider.shared

    private var timelineGroupingVersion: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.id)
            hasher.combine(entry.entryDate.timeIntervalSinceReferenceDate)
            hasher.combine(entry.updatedAt.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }

    private var currentInsightsRefreshKey: ReviewInsightsRefreshKey {
        ReviewInsightsRefreshKey(
            weekStart: currentWeekStart,
            useAIReviewInsights: useAIReviewInsights,
            entrySnapshots: weeklyEntriesForRefresh.map {
                ReviewEntrySnapshot(id: $0.id, updatedAt: $0.updatedAt)
            }
        )
    }

    private var currentWeekRange: Range<Date> {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        return currentWeekStart..<weekEnd
    }

    private var weeklyEntriesForRefresh: [JournalEntry] {
        entries.filter { currentWeekRange.contains($0.entryDate) }
    }

    private var currentWeekStart: Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? calendar.startOfDay(for: Date())
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
        .task(id: currentInsightsRefreshKey) {
            guard selectedMode == .insights else { return }
            await refreshReviewInsights()
        }
        .onChange(of: selectedMode) { _, newMode in
            guard newMode == .insights else { return }
            Task {
                await refreshReviewInsights()
            }
        }
        .task(id: timelineGroupingVersion) {
            refreshTimelineGroups()
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
                HStack(spacing: 6) {
                    ForEach(ReviewMode.allCases) { mode in
                        Button {
                            selectedMode = mode
                        } label: {
                            Text(mode.localizedTitle)
                                .font(AppTheme.warmPaperBody.weight(.semibold))
                                .foregroundStyle(mode == selectedMode ? AppTheme.onAccent : AppTheme.textMuted)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(mode == selectedMode ? AppTheme.accent : .clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mode.localizedTitle)
                        .accessibilityAddTraits(mode == selectedMode ? [.isSelected] : [])
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.paper)
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "Review mode"))
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
                ForEach(timelineGroups, id: \.key) { group in
                    Section {
                        ForEach(group.entries, id: \.id) { entry in
                            NavigationLink {
                                JournalScreen(entryDate: entry.entryDate)
                            } label: {
                                HistoryRow(entry: entry)
                            }
                            .accessibilityLabel(accessibilityTimelineRowLabel(for: entry))
                            .accessibilityHint(String(localized: "Opens this day's journal entry."))
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
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
    }

    @MainActor
    private func refreshReviewInsights(force: Bool = false) async {
        guard selectedMode == .insights else { return }
        guard !entries.isEmpty else {
            reviewInsights = nil
            isLoadingInsights = false
            lastInsightsRefreshKey = nil
            return
        }

        let refreshKey = currentInsightsRefreshKey
        let shouldRefresh = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: force,
            hasInsights: reviewInsights != nil,
            previousKey: lastInsightsRefreshKey,
            currentKey: refreshKey
        )
        guard shouldRefresh else { return }

        isLoadingInsights = true
        let generatedInsights = await reviewInsightsProvider.generateInsights(
            from: entries,
            referenceDate: Date(),
            calendar: calendar
        )
        guard !Task.isCancelled else {
            if refreshKey == currentInsightsRefreshKey {
                isLoadingInsights = false
            }
            return
        }
        guard refreshKey == currentInsightsRefreshKey else {
            return
        }

        reviewInsights = generatedInsights
        lastInsightsRefreshKey = shouldCacheRefreshKey(for: generatedInsights) ? refreshKey : nil
        isLoadingInsights = false
    }

    private func monthYearString(from date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func shouldCacheRefreshKey(for insights: ReviewInsights) -> Bool {
        guard useAIReviewInsights else { return true }
        return insights.source == .cloudAI
    }

    private func refreshTimelineGroups() {
        timelineGroups = HistoryEntryGrouping.groupedByMonth(entries: entries, calendar: calendar)
    }

    private func accessibilityTimelineRowLabel(for entry: JournalEntry) -> String {
        let dateText = entry.entryDate.formatted(date: .complete, time: .omitted)
        return String(
            format: String(localized: "%1$@, %2$@"),
            dateText,
            completionText(for: entry.completionLevel)
        )
    }

    private func completionText(for completionLevel: JournalCompletionLevel) -> String {
        switch completionLevel {
        case .fullFiveCubed:
            return String(localized: "Perfect Daily Rhythm")
        case .standardReflection:
            return String(localized: "Full 15 Complete")
        case .quickCheckIn:
            return String(localized: "Reflection Started")
        case .none:
            return String(localized: "No completion level")
        }
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
                .frame(minWidth: 78, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var completionBadge: some View {
        switch entry.completionLevel {
        case .fullFiveCubed:
            statusChip(
                text: String(localized: "Perfect Daily Rhythm"),
                textColor: AppTheme.textPrimary,
                backgroundColor: AppTheme.complete.opacity(0.18),
                borderColor: AppTheme.completeText
            )
        case .standardReflection:
            statusChip(
                text: String(localized: "Full 15 Complete"),
                textColor: AppTheme.textPrimary,
                backgroundColor: AppTheme.accent.opacity(0.18),
                borderColor: AppTheme.accent
            )
        case .quickCheckIn:
            statusChip(
                text: String(localized: "Reflection Started"),
                textColor: AppTheme.textPrimary,
                backgroundColor: AppTheme.background,
                borderColor: AppTheme.textMuted
            )
        case .none:
            EmptyView()
        }
    }

    private func statusChip(
        text: String,
        textColor: Color,
        backgroundColor: Color,
        borderColor: Color
    ) -> some View {
        Text(text)
            .font(AppTheme.warmPaperBody.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor.opacity(0.8), lineWidth: 1)
            )
    }
}

private struct ReviewSummaryCard: View {
    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.textMuted)

                if let narrativeSummary = insights.narrativeSummary, !narrativeSummary.isEmpty {
                    Text(narrativeSummary)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(4)
                }

                if !insights.weeklyInsights.isEmpty {
                    ReviewWeeklyInsightsSection(items: insights.weeklyInsights)
                } else {
                    Text(insights.resurfacingMessage)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.textMuted)
                        .lineSpacing(2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Continue with"))
                            .font(AppTheme.warmPaperBody.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(insights.continuityPrompt)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(3)
                    }
                }

                ReviewThemeRow(title: String(localized: "Recurring Gratitudes"), items: insights.recurringGratitudes)
                ReviewThemeRow(title: String(localized: "Recurring Needs"), items: insights.recurringNeeds)
                ReviewThemeRow(title: String(localized: "People in Mind"), items: insights.recurringPeople)
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

private struct ReviewWeeklyInsightsSection: View {
    let items: [ReviewWeeklyInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Insights"))
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(Array(items.enumerated()), id: \.offset) { indexedItem in
                VStack(alignment: .leading, spacing: 4) {
                    Text(indexedItem.element.observation)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(2)

                    if let action = indexedItem.element.action, !action.isEmpty {
                        Text(action)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.textMuted)
                            .lineSpacing(2)
                    }
                }
                .padding(10)
                .background(AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct ReviewThemeRow: View {
    let title: String
    let items: [ReviewInsightTheme]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if items.isEmpty {
                Text(String(localized: "No recurring patterns yet"))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { indexedItem in
                        Text(
                            String(
                                format: String(localized: "%1$@ (%2$lld)"),
                                indexedItem.element.label,
                                indexedItem.element.count
                            )
                        )
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textMuted)
                        .lineSpacing(2)
                    }
                }
            }
        }
    }
}
