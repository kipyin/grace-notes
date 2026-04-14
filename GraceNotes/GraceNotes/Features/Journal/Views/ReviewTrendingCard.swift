import SwiftUI

struct ReviewTrendingCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var themeDrilldown: ReviewThemeDrilldownPayload?
    @Binding var browseAllPayload: TrendingBrowsePayload?

    let insights: ReviewInsights?
    let isLoading: Bool

    private var hasTrendingThemes: Bool {
        guard let insights else { return false }
        return !insights.weekStats.movementThemes.isEmpty
    }

    var body: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "review.labels.trending"),
            panelChrome: .standard
        ) {
            panelInner
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var panelInner: some View {
        if isLoading, insights == nil {
            trendingLoadingSkeleton
        } else if let insights, hasTrendingThemes {
            if isLoading {
                trendingThemesContent(buckets: insights.weekStats.trendingBuckets)
                    .accessibilityHint(String(localized: "review.insights.updatedWhenReady"))
                    .accessibilityAddTraits(.updatesFrequently)
            } else {
                trendingThemesContent(buckets: insights.weekStats.trendingBuckets)
            }
        } else {
            Text(String(localized: "review.insights.keepWritingForTrends"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ReviewTrendingEmptyState")
        }
    }

    private var trendingLoadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array([(1.0, 11), (0.82, 11), (0.7, 11)].enumerated()), id: \.offset) { _, spec in
                InsightsPlaceholderBar(widthFraction: spec.0, height: spec.1)
            }
        }
        .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "review.insights.loading"))
    }

    private func trendingThemesContent(buckets: ReviewTrendingBuckets) -> some View {
        let themes = buckets.flattened
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(themes.prefix(3))) { theme in
                    trendingThemeRow(theme)
                }
            }
            if themes.count > 3 {
                Button {
                    browseAllPayload = TrendingBrowsePayload(buckets: buckets)
                } label: {
                    browseAllLabel(title: String(localized: "review.actions.browseTrendingThemes"))
                }
                .buttonStyle(PastTappablePressStyle())
                .accessibilityIdentifier("BrowseAllTrendingThemesLink")
            }
        }
    }

    private func trendingThemeRow(_ theme: ReviewMovementTheme) -> some View {
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
                ReviewTrendBadge(trend: theme.trend)
                ReviewTrendCountCapsule(
                    trend: theme.trend,
                    previous: theme.previousWeekCount,
                    current: theme.currentWeekCount,
                    accent: trendColor(theme.trend)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PastTappablePressStyle())
        .accessibilityIdentifier("TrendingThemeRow.\(reviewInsightSanitizedThemeId(theme.id))")
        .accessibilityLabel(
            reviewTrendingThemeRowAccessibilityLabel(
                label: theme.label,
                trend: theme.trend,
                previousWeekCount: theme.previousWeekCount,
                currentWeekCount: theme.currentWeekCount
            )
        )
    }

    private func drilldownPayload(for theme: ReviewMovementTheme) -> ReviewThemeDrilldownPayload {
        let trendText = localizedTrendLabel(theme.trend)
        let subtitle = String(
            format: String(
                localized: "review.insights.weekComparisonCurrentPrevious"
            ),
            Int64(theme.currentWeekCount),
            Int64(theme.previousWeekCount)
        )
        return ReviewThemeDrilldownPayload(
            canonicalConcept: theme.canonicalConcept,
            label: theme.label,
            sectionTitle: String(localized: "review.labels.trending"),
            subtitle: "\(trendText). \(subtitle)",
            trend: theme.trend,
            evidence: theme.evidence,
            journalThemeDisplayLocale: ThemeDrilldownAlternativesBuilder.resolvedLocale(for: theme.evidence)
        )
    }

    private func localizedTrendLabel(_ trend: ReviewThemeTrend) -> String {
        switch trend {
        case .new:
            return String(localized: "common.new")
        case .rising:
            return String(localized: "common.direction.up")
        case .down:
            return String(localized: "common.direction.down")
        case .stable:
            return String(localized: "review.labels.stable")
        }
    }

    private func trendColor(_ trend: ReviewThemeTrend) -> Color {
        switch trend {
        case .new:
            return .blue
        case .rising:
            return .green
        case .down:
            return .orange
        case .stable:
            return AppTheme.reviewStandardBorder
        }
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
}
