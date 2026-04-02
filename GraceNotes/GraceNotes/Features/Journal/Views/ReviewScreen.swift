import SwiftUI
import SwiftData
import UIKit

/// Single active “browse all” presentation. Two separate `sheet(item:)` branches can race on some
/// runtimes (e.g. iOS 18 + small devices), showing the recurring sheet when opening Trending browse.
private enum ReviewBrowseSheet: Identifiable {
    case mostRecurring(MostRecurringBrowsePayload)
    case trending(TrendingBrowsePayload)

    var id: UUID {
        switch self {
        case .mostRecurring(let payload):
            return payload.id
        case .trending(let payload):
            return payload.id
        }
    }
}

struct ReviewScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.entryDate, order: .reverse) private var entries: [JournalEntry]
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue
    @AppStorage(PastStatisticsIntervalPreference.appStorageKey)
    private var pastStatisticsIntervalEncoded = ""
    @State private var reviewInsights: ReviewInsights?
    @State private var isLoadingInsights = false
    @State private var lastInsightsRefreshKey: ReviewInsightsRefreshKey?
    @State private var mostRecurringThemeDrilldown: ReviewThemeDrilldownPayload?
    @State private var browseSheet: ReviewBrowseSheet?
    @State private var trendingThemeDrilldown: ReviewThemeDrilldownPayload?
    @State private var historyDrilldown: ReviewHistoryDrilldownPayload?
    @State private var journalSearchText = ""
    @State private var journalSearchMatches: [JournalSearchMatch] = []
    @FocusState private var isPastSearchFieldFocused: Bool
    @EnvironmentObject private var appNavigation: AppNavigationModel

    private let reviewInsightsProvider = ReviewInsightsProvider.shared
    private let reviewInsightsCache = ReviewInsightsCache.shared
    /// When true, keep Review list chrome even with zero entries so UI tests can navigate.
    private let isUiTestingExperience: Bool

    private enum PastTabListLayout {
        static var cardRowInsets: EdgeInsets {
            let inset = AppTheme.spacingWide
            return EdgeInsets(top: 2, leading: inset, bottom: 6, trailing: inset)
        }

        static var searchBarRowInsets: EdgeInsets {
            let inset = AppTheme.spacingWide
            return EdgeInsets(top: 6, leading: inset, bottom: 8, trailing: inset)
        }
    }

    init() {
        let isUiTesting = ProcessInfo.graceNotesIsRunningUITests
        isUiTestingExperience = isUiTesting
    }

    private var pastStatisticsInterval: PastStatisticsIntervalSelection {
        PastStatisticsIntervalPreference.selection(fromAppStorage: pastStatisticsIntervalEncoded).validated
    }

    private var currentInsightsRefreshKey: ReviewInsightsRefreshKey {
        let now = Date()
        let period = ReviewInsightsPeriod.currentPeriod(containing: now, calendar: calendar)
        return ReviewInsightsRefreshKey(
            weekStart: period.lowerBound,
            entrySnapshots: ReviewInsightsRefreshKey.entrySnapshotsAffectingInsights(
                entries: entries,
                referenceDate: now,
                calendar: calendar,
                pastStatisticsInterval: pastStatisticsInterval,
                currentReviewPeriod: period
            ),
            weekBoundaryPreferenceRawValue: reviewWeekBoundaryRawValue,
            pastStatisticsIntervalToken: pastStatisticsInterval.cacheKeyToken
        )
    }

    private var currentReviewPeriod: Range<Date> {
        ReviewInsightsPeriod.currentPeriod(containing: Date(), calendar: calendar)
    }

    private var calendar: Calendar {
        ReviewWeekBoundaryPreference.resolve(from: reviewWeekBoundaryRawValue)
            .configuredCalendar()
    }

    /// Same instant used when the visible `reviewInsights` were built (Copilot PR #176 follow-up).
    private var insightsReferenceDate: Date {
        reviewInsights?.generatedAt ?? Date()
    }

    private var trimmedJournalSearchQuery: String {
        journalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isPastSearchMode: Bool {
        isPastSearchFieldFocused || !trimmedJournalSearchQuery.isEmpty
    }

    private var mostRecurringBrowseBinding: Binding<MostRecurringBrowsePayload?> {
        Binding(
            get: {
                guard case .mostRecurring(let payload) = browseSheet else { return nil }
                return payload
            },
            set: { newValue in
                if let newValue {
                    browseSheet = .mostRecurring(newValue)
                } else if case .mostRecurring = browseSheet {
                    browseSheet = nil
                }
            }
        )
    }

    private var trendingBrowseBinding: Binding<TrendingBrowsePayload?> {
        Binding(
            get: {
                guard case .trending(let payload) = browseSheet else { return nil }
                return payload
            },
            set: { newValue in
                if let newValue {
                    browseSheet = .trending(newValue)
                } else if case .trending = browseSheet {
                    browseSheet = nil
                }
            }
        )
    }

    var body: some View {
        Group {
            if entries.isEmpty && !isUiTestingExperience {
                emptyStateWithSearch
            } else {
                historyList
            }
        }
        .navigationTitle(String(localized: "Past"))
        .background(AppTheme.reviewBackground)
        .onAppear {
            PerformanceTrace.instant("ReviewScreen.onAppear")
        }
        .task(id: currentInsightsRefreshKey) {
            await hydrateReviewInsightsFromCacheIfNeeded()
            await refreshReviewInsights()
        }
        .task(id: journalSearchText) {
            await PastJournalSearchDebouncer.runDebouncedSearch(
                query: journalSearchText,
                calendar: calendar,
                modelContext: modelContext,
                isTrimmedQueryStillCurrent: { expectedTrimmed in
                    journalSearchText.trimmingCharacters(in: .whitespacesAndNewlines) == expectedTrimmed
                },
                updateMatches: { journalSearchMatches = $0 }
            )
        }
        .sheet(item: $mostRecurringThemeDrilldown) { payload in
            ThemeDrilldownSheet(payload: payload)
        }
        .sheet(item: $trendingThemeDrilldown) { payload in
            ThemeDrilldownSheet(payload: payload)
        }
        .sheet(item: $browseSheet, onDismiss: {
            browseSheet = nil
        }, content: { sheet in
            Group {
                switch sheet {
                case .mostRecurring(let payload):
                    MostRecurringBrowseSheetContainer(
                        themes: payload.themes,
                        referenceDate: payload.referenceDate,
                        calendar: payload.calendar
                    )
                case .trending(let payload):
                    TrendingBrowseSheetContainer(buckets: payload.buckets)
                }
            }
            .id(sheet.id)
        })
        .sheet(item: $historyDrilldown) { payload in
            ReviewHistoryDrilldownSheetContainer(
                payload: payload,
                entries: entries,
                calendar: calendar,
                referenceDate: insightsReferenceDate,
                pastStatisticsInterval: pastStatisticsInterval
            )
        }
    }

    private var emptyStateWithSearch: some View {
        List {
            pastSearchBarSection
            if !isPastSearchMode {
                Section {
                    ContentUnavailableView {
                        Label(String(localized: "No entries yet"), systemImage: "doc.text")
                    } description: {
                        Text(String(localized: "Start with today."))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowInsets(PastTabListLayout.cardRowInsets)
                .listRowBackground(AppTheme.reviewBackground)
                .listRowSeparator(.hidden)
            } else {
                PastJournalSearchResultsList(
                    isAwaitingInput: isPastSearchFieldFocused && trimmedJournalSearchQuery.isEmpty,
                    matches: journalSearchMatches,
                    calendar: calendar,
                    highlightQuery: trimmedJournalSearchQuery,
                    onDismissSearchFocus: dismissPastSearchFocus
                )
            }
        }
        .pastTabListStyle()
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(isPastSearchFieldFocused ? .never : .immediately)
        .background(AppTheme.reviewBackground)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
    }

    private var historyList: some View {
        List {
            pastSearchBarSection
            if !isPastSearchMode {
                insightsSection
            } else {
                PastJournalSearchResultsList(
                    isAwaitingInput: isPastSearchFieldFocused && trimmedJournalSearchQuery.isEmpty,
                    matches: journalSearchMatches,
                    calendar: calendar,
                    highlightQuery: trimmedJournalSearchQuery,
                    onDismissSearchFocus: dismissPastSearchFocus
                )
            }
        }
        .pastTabListStyle()
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(isPastSearchFieldFocused ? .never : .immediately)
        .background(AppTheme.reviewBackground)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
    }

    private var pastSearchBarSection: some View {
        Section {
            PastJournalSearchFieldRow(text: $journalSearchText, searchFocus: $isPastSearchFieldFocused)
                .listRowInsets(PastTabListLayout.searchBarRowInsets)
                .listRowBackground(isPastSearchMode ? Color.clear : AppTheme.reviewBackground)
                .listRowSeparator(.hidden)
        }
    }

    private var insightsSection: some View {
        Section {
            if reviewInsights != nil || isLoadingInsights {
                ReviewDaysYouWrotePanel(
                    insights: reviewInsights,
                    isLoading: isLoadingInsights
                )
                .listRowInsets(PastTabListLayout.cardRowInsets)
                .listRowBackground(AppTheme.reviewBackground)
                .listRowSeparator(.hidden)

                ReviewHistoryGrowthStagesPanel(
                    historyDrilldown: $historyDrilldown,
                    entries: entries,
                    calendar: calendar,
                    referenceDate: insightsReferenceDate,
                    pastStatisticsInterval: pastStatisticsInterval,
                    insights: reviewInsights,
                    isLoading: isLoadingInsights
                )
                .listRowInsets(PastTabListLayout.cardRowInsets)
                .listRowBackground(AppTheme.reviewBackground)
                .listRowSeparator(.hidden)

                ReviewHistorySectionDistributionPanel(
                    historyDrilldown: $historyDrilldown,
                    entries: entries,
                    calendar: calendar,
                    referenceDate: insightsReferenceDate,
                    pastStatisticsInterval: pastStatisticsInterval,
                    insights: reviewInsights,
                    isLoading: isLoadingInsights
                )
                .listRowInsets(PastTabListLayout.cardRowInsets)
                .listRowBackground(AppTheme.reviewBackground)
                .listRowSeparator(.hidden)
            }

            ReviewMostRecurringCard(
                themeDrilldown: $mostRecurringThemeDrilldown,
                browseAllPayload: mostRecurringBrowseBinding,
                insights: reviewInsights,
                isLoading: isLoadingInsights
            )
            .listRowInsets(PastTabListLayout.cardRowInsets)
            .listRowBackground(AppTheme.reviewBackground)
            .listRowSeparator(.hidden)

            ReviewTrendingCard(
                themeDrilldown: $trendingThemeDrilldown,
                browseAllPayload: trendingBrowseBinding,
                insights: reviewInsights,
                isLoading: isLoadingInsights
            )
            .listRowInsets(PastTabListLayout.cardRowInsets)
            .listRowBackground(AppTheme.reviewBackground)
            .listRowSeparator(.hidden)

            ReviewNarrativeSummaryCard(
                insights: reviewInsights,
                isLoading: isLoadingInsights
            )
            .listRowInsets(PastTabListLayout.cardRowInsets)
            .listRowBackground(AppTheme.reviewBackground)
            .listRowSeparator(.hidden)
        }
    }
}

private extension ReviewScreen {
    func dismissPastSearchFocus() {
        isPastSearchFieldFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    @MainActor
    func refreshReviewInsights() async {
        guard !entries.isEmpty else {
            reviewInsights = nil
            isLoadingInsights = false
            lastInsightsRefreshKey = nil
            return
        }

        let refreshKey = currentInsightsRefreshKey
        let shouldRefresh = ReviewInsightsRefreshPolicy.shouldRefresh(
            hasInsights: reviewInsights != nil,
            previousKey: lastInsightsRefreshKey,
            currentKey: refreshKey
        )
        guard shouldRefresh else { return }

        isLoadingInsights = true
        let generatedInsights = await reviewInsightsProvider.generateInsights(
            from: entries,
            referenceDate: Date(),
            calendar: calendar,
            pastStatisticsInterval: pastStatisticsInterval
        )
        guard !Task.isCancelled else {
            isLoadingInsights = false
            return
        }
        if refreshKey != currentInsightsRefreshKey {
            isLoadingInsights = false
            return
        }

        reviewInsights = generatedInsights
        await reviewInsightsCache.storeIfEligible(
            generatedInsights,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: reviewWeekBoundaryRawValue,
            pastStatisticsIntervalToken: pastStatisticsInterval.cacheKeyToken
        )
        lastInsightsRefreshKey = refreshKey
        isLoadingInsights = false
    }

    func hydrateReviewInsightsFromCacheIfNeeded() async {
        guard !entries.isEmpty else { return }
        guard reviewInsights == nil else { return }
        reviewInsights = await reviewInsightsCache.insights(
            forWeekStart: currentReviewPeriod.lowerBound,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: reviewWeekBoundaryRawValue,
            pastStatisticsIntervalToken: pastStatisticsInterval.cacheKeyToken
        )
    }
}

private extension View {
    func pastTabListStyle() -> some View {
        listStyle(.plain)
    }
}
