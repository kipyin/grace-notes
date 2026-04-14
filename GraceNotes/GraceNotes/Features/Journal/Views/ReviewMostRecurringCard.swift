import SwiftUI

struct ReviewMostRecurringCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue
    @AppStorage(PastStatisticsIntervalPreference.appStorageKey)
    private var pastStatisticsIntervalEncoded = ""

    @Binding var themeDrilldown: ReviewThemeDrilldownPayload?
    @Binding var browseAllPayload: MostRecurringBrowsePayload?

    let insights: ReviewInsights?
    let isLoading: Bool

    private var reviewCalendar: Calendar {
        ReviewWeekBoundaryPreference.resolve(from: reviewWeekBoundaryRawValue).configuredCalendar()
    }

    private var shouldShowCard: Bool {
        // Keep the panel mounted while a refresh is in flight so cached empty snapshots do not hide the title.
        if isLoading {
            return true
        }
        if let insights, !insights.weekStats.mostRecurringThemes.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        Group {
            if shouldShowCard {
                cardBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var cardBody: some View {
        if isLoading, insights == nil {
            loadingSkeleton
        } else if let insights {
            contentForInsights(insights)
        }
    }

    private func contentForInsights(_ insights: ReviewInsights) -> some View {
        let themes = insights.weekStats.mostRecurringThemes
        let panel = themesPanel(
            themes: themes,
            referenceDate: insights.generatedAt,
            calendar: reviewCalendar
        )
        return Group {
            if isLoading {
                panel
                    .accessibilityHint(String(localized: "review.insights.updatedWhenReady"))
                    .accessibilityAddTraits(.updatesFrequently)
            } else {
                panel
            }
        }
    }

    private func themesPanel(
        themes: [ReviewMostRecurringTheme],
        referenceDate: Date,
        calendar: Calendar
    ) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "review.labels.mostRecurring"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(themes.prefix(3))) { theme in
                        mostRecurringThemeRow(theme)
                    }
                }
                if themes.count > 3 {
                    Button {
                        browseAllPayload = MostRecurringBrowsePayload(
                            themes: themes,
                            referenceDate: referenceDate,
                            calendar: calendar
                        )
                    } label: {
                        browseAllLabel(title: String(localized: "review.actions.browseRecurringThemes"))
                    }
                    .buttonStyle(PastTappablePressStyle())
                    .accessibilityIdentifier("BrowseAllRecurringThemesLink")
                }
            }
        }
    }

    private func mostRecurringThemeRow(_ theme: ReviewMostRecurringTheme) -> some View {
        Button {
            themeDrilldown = drilldownPayload(for: theme)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(theme.label)
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                ReviewCountBadge(value: theme.totalCount.formatted(), accent: AppTheme.reviewAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PastTappablePressStyle())
        .accessibilityIdentifier("MostRecurringThemeRow.\(reviewInsightSanitizedThemeId(theme.id))")
        .accessibilityLabel(
            String(
                format: String(localized: "journal.share.lineCountsThree"),
                theme.label,
                String(localized: "review.labels.count"),
                Int64(theme.totalCount)
            )
        )
    }

    private func drilldownPayload(for theme: ReviewMostRecurringTheme) -> ReviewThemeDrilldownPayload {
        let selection = PastStatisticsIntervalPreference.selection(fromAppStorage: pastStatisticsIntervalEncoded)
            .validated
        return ReviewThemeDrilldownPayload(
            label: theme.label,
            sectionTitle: String(localized: "review.labels.mostRecurring"),
            subtitle: selection.mostRecurringDrilldownSubtitle(mentionCount: theme.totalCount),
            trend: nil,
            evidence: theme.evidence
        )
    }

    private func browseAllLabel(title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.reviewAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingSkeleton: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "review.labels.mostRecurring"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array([(1.0, 11), (0.78, 11), (0.66, 11)].enumerated()), id: \.offset) { _, spec in
                    InsightsPlaceholderBar(widthFraction: spec.0, height: spec.1)
                }
            }
            .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
            // Match ReviewTrendingCard: one “loading” node under the title instead of silent placeholder chrome.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "review.insights.loading"))
        }
    }
}
