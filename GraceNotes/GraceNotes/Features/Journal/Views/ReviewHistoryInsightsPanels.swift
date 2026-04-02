import SwiftUI

// MARK: - Growth stages (history skyline)

/// History-scoped completion mix as a five-column skyline (``.empty`` → ``.full``). Issue #152.
struct ReviewHistoryGrowthStagesPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        Group {
            if let insights {
                loadedPanel(for: insights)
            } else if isLoading {
                growthStagesLoadingSkeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .modifier(ReviewHistoryPanelUITestID(identifier: "ReviewHistoryGrowthStagesPanel"))
    }

    @ViewBuilder
    private func loadedPanel(for insights: ReviewInsights) -> some View {
        if isLoading {
            growthSkylineContent(mix: insights.weekStats.historyCompletionMix)
                .accessibilityHint(String(localized: "Updated insights appear when ready."))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            growthSkylineContent(mix: insights.weekStats.historyCompletionMix)
        }
    }

    private func growthSkylineContent(mix: ReviewWeekCompletionMix) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Growth stages"),
            panelChrome: .standard
        ) {
            ReviewHistoryGrowthSkyline(mix: mix, dynamicTypeSize: dynamicTypeSize)
        }
    }

    private var growthStagesLoadingSkeleton: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Growth stages"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 10) {
                InsightsPlaceholderBar(widthFraction: 1.0, height: 72)
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        InsightsPlaceholderBar(widthFraction: 0.14, height: 28)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading weekly insights."))
    }
}

private struct ReviewHistoryGrowthSkyline: View {
    let mix: ReviewWeekCompletionMix
    let dynamicTypeSize: DynamicTypeSize

    private static let columnOrder: [JournalCompletionLevel] = [
        .empty, .started, .growing, .balanced, .full
    ]

    var body: some View {
        let metrics = SkylineMetrics(dynamicTypeSize: dynamicTypeSize)
        let counts = Self.columnOrder.map { count(for: $0, mix: mix) }
        let maxCount = max(counts.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: metrics.columnSpacing) {
            ForEach(Array(Self.columnOrder.enumerated()), id: \.offset) { index, level in
                GrowthSkylineColumn(
                    level: level,
                    count: counts[index],
                    maxCount: maxCount,
                    metrics: metrics
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
    }

    private func count(for level: JournalCompletionLevel, mix: ReviewWeekCompletionMix) -> Int {
        switch level {
        case .empty:
            mix.emptyDays
        case .started:
            mix.startedDays
        case .growing:
            mix.growingDays
        case .balanced:
            mix.balancedDays
        case .full:
            mix.fullDays
        }
    }

    private struct SkylineMetrics {
        let chartHeight: CGFloat
        let minBarHeight: CGFloat
        let columnSpacing: CGFloat
        let glyphSize: CGFloat
        let glyphChrome: CGFloat

        init(dynamicTypeSize: DynamicTypeSize) {
            let scale = ReviewHistoryPanelLayoutScale.skylineMetricsScale(for: dynamicTypeSize)
            chartHeight = (88 * scale).rounded(.toNearestOrAwayFromZero)
            minBarHeight = (6 * scale).rounded(.toNearestOrAwayFromZero)
            columnSpacing = max(3, (5 * scale).rounded(.toNearestOrAwayFromZero))
            glyphSize = (14 * scale).rounded(.toNearestOrAwayFromZero)
            glyphChrome = (26 * scale).rounded(.toNearestOrAwayFromZero)
        }
    }

    private struct GrowthSkylineColumn: View {
        let level: JournalCompletionLevel
        let count: Int
        let maxCount: Int
        let metrics: SkylineMetrics

        private var barHeight: CGFloat {
            guard maxCount > 0 else { return metrics.minBarHeight }
            let fraction = CGFloat(count) / CGFloat(maxCount)
            return max(min(metrics.chartHeight * fraction, metrics.chartHeight), metrics.minBarHeight)
        }

        var body: some View {
            VStack(spacing: 7) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.reviewRhythmColumnFill.opacity(0.42))
                        .frame(height: metrics.chartHeight)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.reviewRhythmPillBackground(for: level))
                        .frame(height: barHeight)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(AppTheme.reviewRhythmPillBorder(for: level), lineWidth: 0.8)
                        }
                }
                .frame(height: metrics.chartHeight)

                Image(ReviewRhythmFormatting.assetName(for: level))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppTheme.reviewRhythmIconTint)
                    .frame(width: metrics.glyphSize, height: metrics.glyphSize)
                    .frame(width: metrics.glyphChrome, height: metrics.glyphChrome)
                    .background {
                        Capsule(style: .continuous)
                            .fill(AppTheme.reviewRhythmPillBackground(for: level))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.reviewRhythmPillBorder(for: level), lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                Text("\(count)")
                    .font(AppTheme.warmPaperCaption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.reviewTextMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(
                    format: String(localized: "%1$@, %2$d"),
                    ReviewCompletionLevelFormatting.accessibilityLocalizedStageName(for: level),
                    count
                )
            )
        }
    }
}

// MARK: - Section distribution (history strip)

/// Proportional segment widths for the Section Distribution strip (issue #152, variant A).
enum ReviewSectionDistributionStripLayout {
    /// Widths for three segments: Gratitudes, Needs, People. All-zero counts yield equal thirds of `usableWidth`.
    static func segmentWidths(
        gratitudeMentions: Int,
        needMentions: Int,
        peopleMentions: Int,
        usableWidth: CGFloat
    ) -> [CGFloat] {
        let counts = [gratitudeMentions, needMentions, peopleMentions]
        let totalLines = counts.reduce(0, +)
        let denominators: [CGFloat] = if totalLines == 0 {
            [1, 1, 1]
        } else {
            counts.map { CGFloat($0) }
        }
        let sumCounts = denominators.reduce(0, +)
        guard sumCounts > 0, usableWidth > 0 else {
            let third = max(usableWidth / 3, 1)
            return [third, third, third]
        }
        var widths = denominators.map { usableWidth * $0 / sumCounts }
        widths = widths.map { max($0, 1) }
        let sumW = widths.reduce(0, +)
        if sumW > 0 {
            widths = widths.map { $0 * usableWidth / sumW }
        }
        return widths
    }
}

/// History-scoped section line totals as a proportion strip + legend. Issue #152.
struct ReviewHistorySectionDistributionPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        Group {
            if let insights {
                loadedPanel(for: insights)
            } else if isLoading {
                sectionDistributionLoadingSkeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .modifier(ReviewHistoryPanelUITestID(identifier: "ReviewHistorySectionDistributionPanel"))
    }

    @ViewBuilder
    private func loadedPanel(for insights: ReviewInsights) -> some View {
        if isLoading {
            sectionStripContent(totals: insights.weekStats.historySectionTotals)
                .accessibilityHint(String(localized: "Updated insights appear when ready."))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            sectionStripContent(totals: insights.weekStats.historySectionTotals)
        }
    }

    private func sectionStripContent(totals: ReviewWeekSectionTotals) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Section Distribution"),
            panelChrome: .standard
        ) {
            ReviewHistorySectionStrip(totals: totals, dynamicTypeSize: dynamicTypeSize)
        }
    }

    private var sectionDistributionLoadingSkeleton: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Section Distribution"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 10) {
                InsightsPlaceholderBar(widthFraction: 1.0, height: 22)
                ForEach(Array([(1.0, 11), (0.88, 11), (0.76, 11)].enumerated()), id: \.offset) { _, spec in
                    InsightsPlaceholderBar(widthFraction: spec.0, height: spec.1)
                }
            }
        }
        .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading weekly insights."))
    }
}

private struct ReviewHistorySectionStrip: View {
    let totals: ReviewWeekSectionTotals
    let dynamicTypeSize: DynamicTypeSize

    private var segments: [(kind: ReviewStatsSectionKind, count: Int)] {
        [
            (.gratitudes, totals.gratitudeMentions),
            (.needs, totals.needMentions),
            (.people, totals.peopleMentions)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let spacing: CGFloat = 4
                let usable = max(width - spacing * 2, 1)
                let segmentWidths = ReviewSectionDistributionStripLayout.segmentWidths(
                    gratitudeMentions: totals.gratitudeMentions,
                    needMentions: totals.needMentions,
                    peopleMentions: totals.peopleMentions,
                    usableWidth: usable
                )
                let stripHeight = max(
                    22,
                    ReviewHistoryPanelLayoutScale.stripHeight(22, dynamicTypeSize: dynamicTypeSize)
                )
                HStack(spacing: spacing) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, item in
                        let fill = SectionDistributionPalette.fill(for: item.kind)
                            .opacity(item.count > 0 ? 1 : 0.38)
                        let border = SectionDistributionPalette.border(for: item.kind)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(fill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(border, lineWidth: 0.85)
                                }
                            Text("\(item.count)")
                                .font(AppTheme.warmPaperMeta)
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.45)
                                .padding(.horizontal, 3)
                                .accessibilityHidden(true)
                        }
                        .frame(width: segmentWidths[index], height: stripHeight)
                        .accessibilityLabel(
                            String(
                                format: String(localized: "%1$@, %2$d"),
                                localizedSectionName(for: item.kind),
                                item.count
                            )
                        )
                    }
                }
                .frame(width: width, height: stripHeight)
            }
            .frame(height: max(26, ReviewHistoryPanelLayoutScale.stripHeight(26, dynamicTypeSize: dynamicTypeSize)))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(SectionDistributionPalette.fill(for: item.kind))
                            .frame(width: 10, height: 10)
                            .overlay {
                                Circle()
                                    .strokeBorder(SectionDistributionPalette.border(for: item.kind), lineWidth: 0.6)
                            }
                            .accessibilityHidden(true)
                        Text(localizedSectionName(for: item.kind))
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                        Spacer(minLength: 8)
                        Text("\(item.count)")
                            .font(AppTheme.warmPaperMeta)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.top, 2)
    }

    private func localizedSectionName(for kind: ReviewStatsSectionKind) -> String {
        switch kind {
        case .gratitudes:
            String(localized: "Gratitudes")
        case .needs:
            String(localized: "Needs")
        case .people:
            String(localized: "People in Mind")
        }
    }
}

private enum SectionDistributionPalette {
    static func fill(for kind: ReviewStatsSectionKind) -> Color {
        switch kind {
        case .gratitudes:
            AppTheme.reviewCompleteBackground
        case .needs:
            AppTheme.reviewStandardBackground
        case .people:
            AppTheme.reviewQuickStartBackground
        }
    }

    static func border(for kind: ReviewStatsSectionKind) -> Color {
        switch kind {
        case .gratitudes:
            AppTheme.reviewCompleteBorder.opacity(0.88)
        case .needs:
            AppTheme.reviewStandardBorder.opacity(0.88)
        case .people:
            AppTheme.reviewQuickStartBorder.opacity(0.88)
        }
    }
}

// MARK: - Shared formatting

enum ReviewCompletionLevelFormatting {
    /// VoiceOver: abstract stages (Empty…Full), not rhythm metaphors (Soil…Bloom). Issue #152.
    static func accessibilityLocalizedStageName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .empty:
            String(localized: "Review growth stage accessibility Empty")
        case .started:
            String(localized: "Review growth stage accessibility Started")
        case .growing:
            String(localized: "Review growth stage accessibility Growing")
        case .balanced:
            String(localized: "Review growth stage accessibility Balanced")
        case .full:
            String(localized: "Review growth stage accessibility Full")
        }
    }
}

// MARK: - UI test hook

private struct ReviewHistoryPanelUITestID: ViewModifier {
    let identifier: String

    func body(content: Content) -> some View {
        if ProcessInfo.graceNotesIsRunningUITests {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private enum ReviewHistoryPanelLayoutScale {
    // Aligns with reflection rhythm column scaling.
    // swiftlint:disable:next cyclomatic_complexity
    static func skylineMetricsScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 0.9
        case .small: return 0.94
        case .medium, .large: return 1.0
        case .xLarge: return 1.05
        case .xxLarge: return 1.1
        case .xxxLarge: return 1.15
        case .accessibility1: return 1.18
        case .accessibility2: return 1.24
        case .accessibility3: return 1.3
        case .accessibility4: return 1.36
        case .accessibility5: return 1.42
        @unknown default: return 1.2
        }
    }

    static func stripHeight(_ base: CGFloat, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        (base * stripRowScale(for: dynamicTypeSize)).rounded(.toNearestOrAwayFromZero)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func stripRowScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 0.92
        case .small: return 0.96
        case .medium, .large: return 1.0
        case .xLarge: return 1.04
        case .xxLarge: return 1.08
        case .xxxLarge: return 1.12
        case .accessibility1: return 1.15
        case .accessibility2: return 1.2
        case .accessibility3: return 1.24
        case .accessibility4: return 1.28
        case .accessibility5: return 1.32
        @unknown default: return 1.18
        }
    }
}
