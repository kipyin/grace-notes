import SwiftUI

// MARK: - Presentation (test hooks)

enum ReviewWeekStatsPresentation {
    static func sectionTotalRows(
        from totals: ReviewWeekSectionTotals
    ) -> [(section: ReviewStatsSectionKind, count: Int)] {
        [
            (.gratitudes, totals.gratitudeMentions),
            (.needs, totals.needMentions),
            (.people, totals.peopleMentions)
        ]
    }

    static func completionMixRows(
        from mix: ReviewWeekCompletionMix
    ) -> [(level: JournalCompletionLevel, count: Int)] {
        [
            (.empty, mix.emptyDays),
            (.started, mix.startedDays),
            (.growing, mix.growingDays),
            (.balanced, mix.balancedDays),
            (.full, mix.fullDays)
        ]
    }

    static func localizedSectionTitle(for section: ReviewStatsSectionKind) -> String {
        switch section {
        case .gratitudes:
            String(localized: "Gratitudes")
        case .needs:
            String(localized: "Needs")
        case .people:
            String(localized: "People in Mind")
        }
    }

    static func localizedCompletionTierName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .empty:
            String(localized: "Empty")
        case .started:
            String(localized: "Started")
        case .growing:
            String(localized: "Growing")
        case .balanced:
            String(localized: "Balanced")
        case .full:
            String(localized: "Full")
        }
    }
}

// MARK: - Panels

struct ReviewWeekSectionTotalsPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        Group {
            if let insights {
                sectionTotalsContent(for: insights)
            } else if isLoading {
                sectionTotalsLoadingSkeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .accessibilityIdentifier("ReviewWeekSectionTotalsPanel")
    }

    @ViewBuilder
    private func sectionTotalsContent(for insights: ReviewInsights) -> some View {
        let panel = sectionTotalsPanel(stats: insights.weekStats)
        if isLoading {
            panel
                .accessibilityHint(String(localized: "Updated insights appear when ready."))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            panel
        }
    }

    private func sectionTotalsPanel(stats: ReviewWeekStats) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Section activity"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 8) {
                let numberedRows = Array(
                    ReviewWeekStatsPresentation.sectionTotalRows(from: stats.sectionTotals).enumerated()
                )
                ForEach(numberedRows, id: \.offset) { _, row in
                    let title = ReviewWeekStatsPresentation.localizedSectionTitle(for: row.section)
                    sectionTotalsRow(label: title, count: row.count)
                }
            }
        }
    }

    private func sectionTotalsRow(label: String, count: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            ReviewCountBadge(value: count.formatted(), accent: AppTheme.reviewAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: String(localized: "%1$@, %2$@, %3$lld"),
                label,
                String(localized: "Count"),
                Int64(count)
            )
        )
    }

    private var sectionTotalsLoadingSkeleton: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Section activity"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array([(1.0, 11), (0.78, 11), (0.66, 11)].enumerated()), id: \.offset) { _, spec in
                    InsightsPlaceholderBar(widthFraction: spec.0, height: spec.1)
                }
            }
        }
        .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading weekly insights."))
    }
}

struct ReviewWeekCompletionMixPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        Group {
            if let insights {
                completionMixContent(for: insights)
            } else if isLoading {
                completionMixLoadingSkeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .accessibilityIdentifier("ReviewWeekCompletionMixPanel")
    }

    @ViewBuilder
    private func completionMixContent(for insights: ReviewInsights) -> some View {
        let panel = completionMixPanel(stats: insights.weekStats)
        if isLoading {
            panel
                .accessibilityHint(String(localized: "Updated insights appear when ready."))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            panel
        }
    }

    private func completionMixPanel(stats: ReviewWeekStats) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Completion this week"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 8) {
                let mixRows = Array(
                    ReviewWeekStatsPresentation.completionMixRows(from: stats.completionMix).enumerated()
                )
                ForEach(mixRows, id: \.offset) { _, row in
                    let tierLabel = ReviewWeekStatsPresentation.localizedCompletionTierName(for: row.level)
                    completionMixRow(
                        label: tierLabel,
                        count: row.count,
                        accessibilityLevelId: row.level.rawValue
                    )
                }
                let footnote = String(
                    localized: "Each row counts a day with a saved entry, not every calendar day in the week."
                )
                Text(footnote)
                    .font(AppTheme.warmPaperCaption)
                    .foregroundStyle(AppTheme.reviewTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private func completionMixRow(label: String, count: Int, accessibilityLevelId: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            ReviewCountBadge(value: count.formatted(), accent: AppTheme.reviewAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ReviewWeekCompletionMixRow.\(accessibilityLevelId)")
        .accessibilityLabel(
            String(
                format: String(localized: "%1$@, %2$@, %3$lld"),
                label,
                String(localized: "Count"),
                Int64(count)
            )
        )
    }

    private var completionMixLoadingSkeleton: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Completion this week"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 10) {
                let completionBarSpecs: [(CGFloat, CGFloat)] = [
                    (1.0, 11), (0.92, 11), (0.84, 11), (0.76, 11), (0.68, 11)
                ]
                ForEach(Array(completionBarSpecs.enumerated()), id: \.offset) { _, spec in
                    InsightsPlaceholderBar(widthFraction: spec.0, height: spec.1)
                }
                InsightsPlaceholderBar(widthFraction: 0.95, height: 9)
            }
        }
        .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading weekly insights."))
    }
}
