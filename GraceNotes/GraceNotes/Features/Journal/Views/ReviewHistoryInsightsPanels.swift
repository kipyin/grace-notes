import SwiftUI

// MARK: - Growth stages (history skyline)

/// History-scoped completion mix as a five-column skyline (``.soil`` → ``.bloom``). Issue #152.
struct ReviewHistoryGrowthStagesPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var historyDrilldown: ReviewHistoryDrilldownPayload?
    let entries: [Journal]
    let calendar: Calendar
    let referenceDate: Date
    let pastStatisticsInterval: PastStatisticsIntervalSelection

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
                .accessibilityHint(String(localized: "review.insights.updatedWhenReady"))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            growthSkylineContent(mix: insights.weekStats.historyCompletionMix)
        }
    }

    private func growthSkylineContent(mix: ReviewWeekCompletionMix) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "review.labels.growthStages"),
            panelChrome: .standard
        ) {
            ReviewHistoryGrowthSkyline(
                mix: mix,
                dynamicTypeSize: dynamicTypeSize,
                onSelectGrowthStage: { level in
                    historyDrilldown = .growthStage(level)
                }
            )
        }
    }

    private var growthStagesLoadingSkeleton: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "review.labels.growthStages"),
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
        .accessibilityLabel(String(localized: "review.insights.loading"))
    }
}

private struct ReviewHistoryGrowthSkyline: View {
    let mix: ReviewWeekCompletionMix
    let dynamicTypeSize: DynamicTypeSize
    let onSelectGrowthStage: (JournalCompletionLevel) -> Void

    private static let columnOrder: [JournalCompletionLevel] = [
        .soil, .sprout, .twig, .leaf, .bloom
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
                    metrics: metrics,
                    dynamicTypeSize: dynamicTypeSize,
                    onSelect: {
                        onSelectGrowthStage(level)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
    }

    private func count(for level: JournalCompletionLevel, mix: ReviewWeekCompletionMix) -> Int {
        switch level {
        case .soil:
            mix.soilDayCount
        case .sprout:
            mix.sproutDayCount
        case .twig:
            mix.twigDayCount
        case .leaf:
            mix.leafDayCount
        case .bloom:
            mix.bloomDayCount
        }
    }

    private struct SkylineMetrics {
        let chartHeight: CGFloat
        let minBarHeight: CGFloat
        let columnSpacing: CGFloat

        init(dynamicTypeSize: DynamicTypeSize) {
            let scale = ReviewHistoryPanelLayoutScale.skylineMetricsScale(for: dynamicTypeSize)
            chartHeight = (88 * scale).rounded(.toNearestOrAwayFromZero)
            minBarHeight = (6 * scale).rounded(.toNearestOrAwayFromZero)
            columnSpacing = max(3, (5 * scale).rounded(.toNearestOrAwayFromZero))
        }
    }

    private struct GrowthSkylineColumn: View {
        let level: JournalCompletionLevel
        let count: Int
        let maxCount: Int
        let metrics: SkylineMetrics
        let dynamicTypeSize: DynamicTypeSize
        let onSelect: () -> Void

        private var barHeight: CGFloat {
            guard maxCount > 0 else { return metrics.minBarHeight }
            let fraction = CGFloat(count) / CGFloat(maxCount)
            return max(min(metrics.chartHeight * fraction, metrics.chartHeight), metrics.minBarHeight)
        }

        private var columnAccessibilityLabel: String {
            String(
                format: String(localized: "journal.share.twoColumnRow"),
                ReviewCompletionLevelFormatting.accessibilityLocalizedStageName(for: level),
                count
            )
        }

        var body: some View {
            Button(action: onSelect) {
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

                    ReviewGrowthStageSkylineGlyph(level: level, dynamicTypeSize: dynamicTypeSize)

                    Text("\(count)")
                        .font(AppTheme.warmPaperCaption)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PastTappablePressStyle())
            .disabled(count == 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(columnAccessibilityLabel)
            .accessibilityHint(
                count == 0
                    ? String(localized: "accessibility.reviewHistory.growthColumnEmpty")
                    : String(localized: "accessibility.reviewHistory.growthColumn")
            )
            .accessibilityAddTraits(count == 0 ? [] : .isButton)
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

    /// Display percentages for the section-mix strip (issue #247). Whole numbers only; uses the largest-remainder
    /// method so the three values always sum to **100** when `total > 0` (plain rounding can yield 99).
    /// When all counts are zero, returns `[0, 0, 0]` so each segment can show `0%` with equal thirds widths.
    static func integerDisplayPercents(
        gratitudeMentions: Int,
        needMentions: Int,
        peopleMentions: Int
    ) -> [Int] {
        let counts = [gratitudeMentions, needMentions, peopleMentions]
        let total = counts.reduce(0, +)
        guard total > 0 else { return [0, 0, 0] }

        // Integer Hamilton (largest remainder): `floor(count * 100 / total)` per bucket, then assign the leftover
        // points (0…2 for three buckets) by largest fractional remainder `(count * 100) % total`.
        // A floating-point floor can make `100 - sum(floors)` exceed 3 and trap when indexing
        // `indicesByLargestFraction`.
        var floors = counts.map { ($0 * 100) / total }
        let remainder = 100 - floors.reduce(0, +)
        let remainderNumerators = counts.map { ($0 * 100) % total }
        let indicesByLargestFraction = (0..<counts.count).sorted { lhs, rhs in
            let left = remainderNumerators[lhs]
            let right = remainderNumerators[rhs]
            if left != right { return left > right }
            return lhs < rhs
        }
        for offset in 0..<remainder {
            floors[indicesByLargestFraction[offset]] += 1
        }
        return floors
    }
}

/// History-scoped section line totals as a proportion strip + legend. Issue #152.
struct ReviewHistorySectionDistributionPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var historyDrilldown: ReviewHistoryDrilldownPayload?
    let entries: [Journal]
    let calendar: Calendar
    let referenceDate: Date
    let pastStatisticsInterval: PastStatisticsIntervalSelection

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
                .accessibilityHint(String(localized: "review.insights.updatedWhenReady"))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            sectionStripContent(totals: insights.weekStats.historySectionTotals)
        }
    }

    private func sectionStripContent(totals: ReviewWeekSectionTotals) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "review.labels.sectionDistribution"),
            panelChrome: .standard
        ) {
            ReviewHistorySectionStrip(
                totals: totals,
                dynamicTypeSize: dynamicTypeSize,
                onSelectSection: { kind in
                    historyDrilldown = .section(kind)
                }
            )
        }
    }

    private var sectionDistributionLoadingSkeleton: some View {
        ReviewInsightInsetPanel(
            title: String(localized: "review.labels.sectionDistribution"),
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
        .accessibilityLabel(String(localized: "review.insights.loading"))
    }
}

private struct ReviewHistorySectionStrip: View {
    let totals: ReviewWeekSectionTotals
    let dynamicTypeSize: DynamicTypeSize
    let onSelectSection: (ReviewStatsSectionKind) -> Void

    private var segments: [(kind: ReviewStatsSectionKind, count: Int)] {
        [
            (.gratitudes, totals.gratitudeMentions),
            (.needs, totals.needMentions),
            (.people, totals.peopleMentions)
        ]
    }

    private func segmentAccessibilityHint(forCount count: Int) -> String {
        count == 0
            ? String(localized: "accessibility.reviewHistory.sectionStripEmpty")
            : String(localized: "accessibility.reviewHistory.sectionStrip")
    }

    var body: some View {
        let percents = ReviewSectionDistributionStripLayout.integerDisplayPercents(
            gratitudeMentions: totals.gratitudeMentions,
            needMentions: totals.needMentions,
            peopleMentions: totals.peopleMentions
        )
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
                        let fill = ReviewSectionDistributionPalette.fill(for: item.kind)
                            .opacity(item.count > 0 ? 1 : 0.38)
                        let border = ReviewSectionDistributionPalette.border(for: item.kind)
                        Button {
                            onSelectSection(item.kind)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(fill)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(border, lineWidth: 0.85)
                                    }
                                Text(
                                    String(
                                        format: String(localized: "review.sectionMix.segmentPercent"),
                                        locale: .current,
                                        Int64(percents[index])
                                    )
                                )
                                .font(AppTheme.warmPaperMeta)
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.45)
                                .padding(.horizontal, 3)
                                .accessibilityHidden(true)
                            }
                            .frame(width: segmentWidths[index], height: stripHeight)
                        }
                        .buttonStyle(PastTappablePressStyle())
                        .disabled(item.count == 0)
                        .accessibilityLabel(
                            sectionMixAccessibilityLabel(
                                kind: item.kind,
                                count: item.count,
                                percent: percents[index]
                            )
                        )
                        .accessibilityHint(segmentAccessibilityHint(forCount: item.count))
                        .accessibilityAddTraits(item.count == 0 ? [] : .isButton)
                    }
                }
                .frame(width: width, height: stripHeight)
            }
            .frame(height: max(26, ReviewHistoryPanelLayoutScale.stripHeight(26, dynamicTypeSize: dynamicTypeSize)))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, item in
                    Button {
                        onSelectSection(item.kind)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Circle()
                                .fill(ReviewSectionDistributionPalette.fill(for: item.kind))
                                .frame(width: 10, height: 10)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            ReviewSectionDistributionPalette.border(for: item.kind),
                                            lineWidth: 0.6
                                        )
                                }
                                .accessibilityHidden(true)
                            Text(localizedSectionName(for: item.kind))
                                .font(AppTheme.warmPaperMeta)
                                .foregroundStyle(AppTheme.reviewTextPrimary)
                            Spacer(minLength: 8)
                            ReviewCountBadge(
                                value: item.count.formatted(),
                                accent: ReviewSectionDistributionPalette.countBadgeAccent(for: item.kind)
                            )
                            .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PastTappablePressStyle())
                    .disabled(item.count == 0)
                    .accessibilityLabel(
                        sectionMixAccessibilityLabel(
                            kind: item.kind,
                            count: item.count,
                            percent: percents[index]
                        )
                    )
                    .accessibilityHint(segmentAccessibilityHint(forCount: item.count))
                    .accessibilityAddTraits(item.count == 0 ? [] : .isButton)
                }
            }
        }
        .padding(.top, 2)
    }

    private func sectionMixAccessibilityLabel(
        kind: ReviewStatsSectionKind,
        count: Int,
        percent: Int
    ) -> String {
        let format = count == 1
            ? String(localized: "accessibility.reviewHistory.sectionMixRow.singular")
            : String(localized: "accessibility.reviewHistory.sectionMixRow.plural")
        return String(
            format: format,
            localizedSectionName(for: kind),
            count,
            percent
        )
    }

    private func localizedSectionName(for kind: ReviewStatsSectionKind) -> String {
        switch kind {
        case .gratitudes:
            String(localized: "journal.section.gratitudesTitle")
        case .needs:
            String(localized: "journal.section.needsTitle")
        case .people:
            String(localized: "journal.section.peopleTitle")
        }
    }
}

enum ReviewSectionDistributionPalette {
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

    /// Accent for `ReviewCountBadge` on section-mix legend rows (full-opacity border hue, issue #247).
    static func countBadgeAccent(for kind: ReviewStatsSectionKind) -> Color {
        switch kind {
        case .gratitudes:
            AppTheme.reviewCompleteBorder
        case .needs:
            AppTheme.reviewStandardBorder
        case .people:
            AppTheme.reviewQuickStartBorder
        }
    }
}

// MARK: - Shared formatting

enum ReviewCompletionLevelFormatting {
    /// VoiceOver: abstract stages (Empty…Full), not rhythm metaphors (Soil…Bloom). Issue #152.
    static func accessibilityLocalizedStageName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            String(localized: "accessibility.reviewGrowthStage.empty")
        case .sprout:
            String(localized: "accessibility.reviewGrowthStage.started")
        case .twig:
            String(localized: "accessibility.reviewGrowthStage.growing")
        case .leaf:
            String(localized: "accessibility.reviewGrowthStage.balanced")
        case .bloom:
            String(localized: "accessibility.reviewGrowthStage.full")
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

enum ReviewHistoryPanelLayoutScale {
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
