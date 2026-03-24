import SwiftUI
import SwiftData

// swiftlint:disable type_body_length
struct ReviewScreen: View {
    private struct TimelineRefreshKey: Hashable {
        let entryCount: Int
        let newestEntryUpdateAt: Date
    }

    private enum ReviewMode: CaseIterable, Hashable, Identifiable {
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
    @State private var selectedMode: ReviewMode
    @State private var lastInsightsRefreshKey: ReviewInsightsRefreshKey?
    @State private var timelineGroups: [(key: Date, entries: [JournalEntry])] = []
    @AppStorage(ReviewInsightsProvider.aiFeaturesEnabledKey) private var aiFeaturesEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let calendar = Calendar.current
    private let reviewInsightsProvider = ReviewInsightsProvider.shared
    /// When true, keep Review list chrome (mode picker + identifiers) even with zero entries so UI tests can navigate.
    private let isUiTestingExperience: Bool

    init() {
        let isUiTesting = ProcessInfo.graceNotesIsRunningUITests
        isUiTestingExperience = isUiTesting
        _selectedMode = State(initialValue: isUiTesting ? .timeline : .insights)
    }

    private var timelineRefreshKey: TimelineRefreshKey {
        TimelineRefreshKey(
            entryCount: entries.count,
            newestEntryUpdateAt: entries.map(\.updatedAt).max() ?? .distantPast
        )
    }

    private var currentInsightsRefreshKey: ReviewInsightsRefreshKey {
        ReviewInsightsRefreshKey(
            weekStart: currentReviewPeriod.lowerBound,
            aiFeaturesEnabled: aiFeaturesEnabled,
            entrySnapshots: weeklyEntriesForRefresh.map {
                ReviewEntrySnapshot(id: $0.id, updatedAt: $0.updatedAt)
            }
        )
    }

    private var currentReviewPeriod: Range<Date> {
        ReviewInsightsPeriod.currentPeriod(containing: Date(), calendar: calendar)
    }

    private var weeklyEntriesForRefresh: [JournalEntry] {
        entries.filter { currentReviewPeriod.contains($0.entryDate) }
    }

    var body: some View {
        Group {
            if entries.isEmpty && !isUiTestingExperience {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle(String(localized: "Review"))
        .background(AppTheme.reviewBackground)
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
        .task(id: timelineRefreshKey) {
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
            reviewModeSection

            switch selectedMode {
            case .insights:
                insightsSection
                insightsPullToRefreshScrollAssist
            case .timeline:
                timelineSections
            }
        }
        .listStyle(.insetGrouped)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: selectedMode)
        .refreshable {
            switch selectedMode {
            case .insights:
                await refreshReviewInsights(force: true)
            case .timeline:
                refreshTimelineGroups()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
    }

    private var reviewModeSection: some View {
        Section {
            ReviewModeSegmentedControl(selectedMode: $selectedMode)
                .listRowBackground(AppTheme.reviewBackground)
        }
    }

    /// System segmented `Picker` so iOS 26+ picks up the platform Liquid Glass styling without custom chrome.
    private struct ReviewModeSegmentedControl: View {
        @Binding var selectedMode: ReviewMode

        var body: some View {
            Picker(selection: $selectedMode) {
                ForEach(ReviewMode.allCases) { mode in
                    Text(mode.localizedTitle)
                        .tag(mode)
                }
            } label: {
                Text(String(localized: "Review mode"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(AppTheme.reviewAccent)
            .accessibilityHint(String(localized: "Choose insights or timeline"))
            .accessibilityIdentifier("ReviewModePicker")
        }
    }

    private var insightsSection: some View {
        Section {
            ReviewSummaryCard(insights: reviewInsights, isLoading: isLoadingInsights)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(AppTheme.reviewBackground)
        }
    }

    /// `List.refreshable` only engages when the scroll view can overscroll; a short insights stack often cannot.
    private var insightsPullToRefreshScrollAssist: some View {
        Section {
            Color.clear
                .frame(height: 280)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var timelineSections: some View {
        ForEach(timelineGroups, id: \.key) { group in
            Section {
                ForEach(group.entries, id: \.id) { entry in
                    NavigationLink {
                        JournalScreen(entryDate: entry.entryDate)
                    } label: {
                        HistoryRow(entry: entry)
                    }
                    .accessibilityLabel(accessibilityTimelineRowLabel(for: entry))
                    .accessibilityIdentifier("ReviewTimelineEntry.\(entry.id.uuidString)")
                    .accessibilityHint(String(localized: "Opens that day's entry."))
                    .listRowBackground(AppTheme.reviewPaper)
                }
            } header: {
                Text(monthYearString(from: group.key))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.reviewTextPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
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

        let previousForForcedRefresh = force ? reviewInsights : nil

        isLoadingInsights = true
        let generatedInsights = await reviewInsightsProvider.generateInsights(
            from: entries,
            referenceDate: Date(),
            calendar: calendar
        )
        guard !Task.isCancelled else {
            isLoadingInsights = false
            return
        }
        if !force, refreshKey != currentInsightsRefreshKey {
            isLoadingInsights = false
            return
        }

        let outcome: ReviewInsightsRefreshPolicy.ForcedRefreshOutcome
        if force {
            outcome = ReviewInsightsRefreshPolicy.forcedRefreshOutcome(
                previous: previousForForcedRefresh,
                generated: generatedInsights
            )
        } else {
            outcome = ReviewInsightsRefreshPolicy.ForcedRefreshOutcome(
                insights: generatedInsights,
                shouldUpdateCachedRefreshKey: true
            )
        }

        reviewInsights = outcome.insights
        if outcome.shouldUpdateCachedRefreshKey {
            lastInsightsRefreshKey = shouldCacheRefreshKey(for: generatedInsights) ? refreshKey : nil
        }
        isLoadingInsights = false
    }

    private func monthYearString(from date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func shouldCacheRefreshKey(for insights: ReviewInsights) -> Bool {
        guard aiFeaturesEnabled else { return true }
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
        case .abundance:
            return String(localized: "Abundance")
        case .harvest:
            return String(localized: "Harvest")
        case .ripening:
            return String(localized: "Ripening")
        case .seed:
            return String(localized: "Seed")
        case .soil:
            return String(localized: "Soil")
        }
    }

}
// swiftlint:enable type_body_length
private struct HistoryRow: View {
    let entry: JournalEntry

    var body: some View {
        ViewThatFits(in: .horizontal) {
            compactLayout
            stackedLayout
        }
        .padding(.vertical, 2)
    }

    private var compactLayout: some View {
        HStack(alignment: .center, spacing: 10) {
            dateText
            if hasCompletionBadge {
                Spacer(minLength: 8)
                completionBadge(lineLimit: 1)
            }
        }
    }

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            dateText
            if hasCompletionBadge {
                completionBadge(lineLimit: 2)
            }
        }
    }

    private var dateText: some View {
        Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.reviewTextPrimary)
    }

    private var hasCompletionBadge: Bool { true }

    @ViewBuilder
    private func completionBadge(lineLimit: Int) -> some View {
        switch entry.completionLevel {
        case .abundance:
            statusChip(
                text: String(localized: "Abundance"),
                textColor: AppTheme.reviewCompleteText,
                backgroundColor: AppTheme.reviewCompleteBackground,
                borderColor: AppTheme.reviewCompleteBorder
            )
            .lineLimit(lineLimit)
        case .harvest:
            statusChip(
                text: String(localized: "Harvest"),
                textColor: AppTheme.reviewStandardText,
                backgroundColor: AppTheme.reviewStandardBackground,
                borderColor: AppTheme.reviewStandardBorder
            )
            .lineLimit(lineLimit)
        case .ripening:
            statusChip(
                text: String(localized: "Ripening"),
                textColor: AppTheme.reviewStandardText,
                backgroundColor: AppTheme.reviewStandardBackground,
                borderColor: AppTheme.reviewStandardBorder
            )
            .lineLimit(lineLimit)
        case .seed:
            statusChip(
                text: String(localized: "Seed"),
                textColor: AppTheme.reviewQuickStartText,
                backgroundColor: AppTheme.reviewQuickStartBackground,
                borderColor: AppTheme.reviewQuickStartBorder
            )
            .lineLimit(lineLimit)
        case .soil:
            statusChip(
                text: String(localized: "Soil"),
                textColor: AppTheme.reviewTextMuted,
                backgroundColor: AppTheme.reviewBackground,
                borderColor: AppTheme.border
            )
            .lineLimit(lineLimit)
        }
    }

    private func statusChip(
        text: String,
        textColor: Color,
        backgroundColor: Color,
        borderColor: Color
    ) -> some View {
        Text(text)
            .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(textColor)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor.opacity(0.8), lineWidth: 1)
            )
            .accessibilityLabel(text)
    }
}

private struct ReviewSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "This Week"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .accessibilityAddTraits(.isHeader)

            if isLoading, insights == nil {
                ProgressView()
                    .tint(AppTheme.reviewAccent)
            } else if let insights {
                sourceRow(for: insights.source)

                Text(weekRangeText(insights))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextMuted)

                if shouldShowNarrativeSummary(for: insights),
                   let narrativeSummary = insights.narrativeSummary {
                    Text(narrativeSummary)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextPrimary)
                        .lineSpacing(4)
                }

                if !insights.weeklyInsights.isEmpty {
                    ReviewWeeklyInsightsSection(items: insights.weeklyInsights)
                } else {
                    Text(insights.resurfacingMessage)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .lineSpacing(2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Continue with"))
                            .font(AppTheme.warmPaperBody.weight(.semibold))
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(insights.continuityPrompt)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .lineSpacing(3)
                    }
                }

                ReviewThemeRow(title: String(localized: "Recurring Gratitudes"), items: insights.recurringGratitudes)
                ReviewThemeRow(title: String(localized: "Recurring Needs"), items: insights.recurringNeeds)
                ReviewThemeRow(title: String(localized: "People in Mind"), items: insights.recurringPeople)
            } else {
                Text(String(localized: "Start writing this week to unlock review insights."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.reviewTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(AppTheme.reviewPaper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sourceRow(for source: ReviewInsightSource) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                sourceLabelAndChip(for: source)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    sourceLabelAndChip(for: source)
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    sourceLabelAndChip(for: source)
                }
            }
        }
    }

    private func sourceLabelAndChip(for source: ReviewInsightSource) -> some View {
        HStack(spacing: 8) {
            Text(String(localized: "Source"))
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
            Text(insightSourceText(source))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.reviewBackground)
                .clipShape(Capsule())
        }
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

    private func shouldShowNarrativeSummary(for insights: ReviewInsights) -> Bool {
        guard let narrativeSummary = insights.narrativeSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !narrativeSummary.isEmpty
        else {
            return false
        }
        guard let firstInsightObservation = insights.weeklyInsights.first?.observation else {
            return true
        }
        return normalizedInsightText(narrativeSummary) != normalizedInsightText(firstInsightObservation)
    }

    private func normalizedInsightText(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ReviewWeeklyInsightsSection: View {
    let items: [ReviewWeeklyInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Insights"))
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                VStack(alignment: .leading, spacing: 6) {
                    if index > 0 {
                        Divider()
                    }

                    Text(item.observation)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextPrimary)
                        .lineSpacing(2)

                    if let action = item.action, !action.isEmpty {
                        Text(action)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .lineSpacing(2)
                    }
                }
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
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .accessibilityAddTraits(.isHeader)

            if items.isEmpty {
                Text(String(localized: "No recurring patterns yet"))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.reviewTextMuted)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items, id: \.self) { item in
                        Text(
                            String(
                                format: String(localized: "%1$@ (%2$lld)"),
                                item.label,
                                item.count
                            )
                        )
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .lineSpacing(2)
                    }
                }
            }
        }
    }
}
