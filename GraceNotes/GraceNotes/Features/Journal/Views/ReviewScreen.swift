import SwiftUI
import SwiftData

struct ReviewScreen: View {
    @Query(sort: \JournalEntry.entryDate, order: .reverse) private var entries: [JournalEntry]
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue
    @AppStorage(PastStatisticsIntervalPreference.appStorageKey)
    private var pastStatisticsIntervalEncoded = ""
    @State private var reviewInsights: ReviewInsights?
    @State private var isLoadingInsights = false
    @State private var lastInsightsRefreshKey: ReviewInsightsRefreshKey?
    @State private var mostRecurringThemeDrilldown: ReviewThemeDrilldownPayload?
    @State private var mostRecurringBrowsePayload: MostRecurringBrowsePayload?
    @State private var trendingThemeDrilldown: ReviewThemeDrilldownPayload?
    @State private var trendingBrowsePayload: TrendingBrowsePayload?
    @State private var journalSearchText = ""

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
        .navigationDestination(for: PastJournalSearchRoute.self) { _ in
            PastJournalSearchScreen(text: $journalSearchText, calendar: calendar)
        }
        .sheet(item: $mostRecurringThemeDrilldown) { payload in
            ThemeDrilldownSheet(payload: payload)
        }
        .sheet(item: $mostRecurringBrowsePayload) { payload in
            MostRecurringBrowseSheetContainer(
                themes: payload.themes,
                referenceDate: payload.referenceDate,
                calendar: payload.calendar
            )
        }
        .sheet(item: $trendingThemeDrilldown) { payload in
            ThemeDrilldownSheet(payload: payload)
        }
        .sheet(item: $trendingBrowsePayload) { payload in
            TrendingBrowseSheetContainer(buckets: payload.buckets)
        }
    }

    private var emptyStateWithSearch: some View {
        List {
            pastSearchBarSection
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
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
    }

    private var historyList: some View {
        List {
            pastSearchBarSection
            insightsSection
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
    }

    private var pastSearchBarSection: some View {
        Section {
            NavigationLink(value: PastJournalSearchRoute.journalSearch) {
                PastJournalSearchActivationRow(query: journalSearchText)
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowInsets(PastTabListLayout.searchBarRowInsets)
            .listRowBackground(AppTheme.reviewBackground)
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
                    insights: reviewInsights,
                    isLoading: isLoadingInsights
                )
                .listRowInsets(PastTabListLayout.cardRowInsets)
                .listRowBackground(AppTheme.reviewBackground)
                .listRowSeparator(.hidden)

                ReviewHistorySectionDistributionPanel(
                    insights: reviewInsights,
                    isLoading: isLoadingInsights
                )
                .listRowInsets(PastTabListLayout.cardRowInsets)
                .listRowBackground(AppTheme.reviewBackground)
                .listRowSeparator(.hidden)
            }

            ReviewMostRecurringCard(
                themeDrilldown: $mostRecurringThemeDrilldown,
                browseAllPayload: $mostRecurringBrowsePayload,
                insights: reviewInsights,
                isLoading: isLoadingInsights
            )
            .listRowInsets(PastTabListLayout.cardRowInsets)
            .listRowBackground(AppTheme.reviewBackground)
            .listRowSeparator(.hidden)

            ReviewTrendingCard(
                themeDrilldown: $trendingThemeDrilldown,
                browseAllPayload: $trendingBrowsePayload,
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
