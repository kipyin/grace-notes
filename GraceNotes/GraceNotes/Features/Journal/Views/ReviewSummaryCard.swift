import SwiftUI
import UIKit

private struct ReviewInsightPanelBodies {
    let observation: String
    let thread: String
    let action: String
}

// swiftlint:disable type_body_length file_length
/// “Days you wrote” rhythm strip for the Past tab, as its own list row.
struct ReviewDaysYouWrotePanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue
    let insights: ReviewInsights?
    let isLoading: Bool
    /// When set, persisted rhythm days open via this callback (Past tab sheet).
    /// When `nil`, uses push `NavigationLink` to `JournalScreen`.
    var onPersistedDaySelected: ((Date) -> Void)?

    init(
        insights: ReviewInsights?,
        isLoading: Bool,
        onPersistedDaySelected: ((Date) -> Void)? = nil
    ) {
        self.insights = insights
        self.isLoading = isLoading
        self.onPersistedDaySelected = onPersistedDaySelected
    }

    var body: some View {
        Group {
            if let insights {
                rhythmContentWithLoadingAccessibility(for: insights)
            } else if isLoading {
                RhythmLoadingSkeleton(reduceMotion: reduceMotion)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func rhythmContentWithLoadingAccessibility(for insights: ReviewInsights) -> some View {
        if isLoading {
            weekRhythmPanel(for: insights)
                .accessibilityHint(String(localized: "Updated insights appear when ready."))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            weekRhythmPanel(for: insights)
        }
    }

    private func weekRhythmPanel(for insights: ReviewInsights) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Reflection rhythm"),
            panelChrome: .standard
        ) {
            rhythmHistoryCurve(for: insights)
        }
    }

    /// Seven consecutive local days ending on ``referenceNow`` (typically “today”), merged with rhythm payloads.
    static func rollingRhythmDaysForDisplay(
        _ rawDays: [ReviewDayActivity],
        referenceNow: Date,
        calendar: Calendar
    ) -> (
        days: [ReviewDayActivity],
        displayInterval: Range<Date>
    ) {
        let refStart = calendar.startOfDay(for: referenceNow)
        guard let oldestRaw = calendar.date(byAdding: .day, value: -6, to: refStart),
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: refStart)
        else {
            return ([], refStart..<refStart)
        }
        let oldestStart = calendar.startOfDay(for: oldestRaw)
        let displayInterval = oldestStart..<endExclusive
        var byDay: [Date: ReviewDayActivity] = [:]
        for day in rawDays {
            let dayKey = calendar.startOfDay(for: day.date)
            byDay[dayKey] = day
        }
        var result: [ReviewDayActivity] = []
        for offset in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: oldestStart) else { continue }
            let normalizedDay = calendar.startOfDay(for: dayStart)
            if let existing = byDay[normalizedDay] {
                result.append(existing)
            } else {
                result.append(
                    ReviewDayActivity(
                        date: normalizedDay,
                        hasReflectiveActivity: false,
                        hasPersistedEntry: false
                    )
                )
            }
        }
        return (result, displayInterval)
    }

    private var reviewRhythmCalendar: Calendar {
        ReviewWeekBoundaryPreference.resolve(from: reviewWeekBoundaryRawValue)
            .configuredCalendar()
    }

    private func rhythmHistoryCurve(for insights: ReviewInsights) -> some View {
        let stats = insights.weekStats
        let rawDays = stats.rhythmHistory ?? stats.activity
        let referenceNow = Date()
        let calendar = reviewRhythmCalendar
        let (days, displayInterval) = Self.rollingRhythmDaysForDisplay(
            rawDays,
            referenceNow: referenceNow,
            calendar: calendar
        )
        let metrics = RhythmCurveScaledMetrics(dynamicTypeSize: dynamicTypeSize)
        let pinStart = days.first.map { calendar.startOfDay(for: $0.date) } ?? insights.weekStart
        let pinIdentity = ReviewRhythmScrollPinIdentity(weekStart: pinStart, days: days)
        return rhythmHistoryScrollSection(
            days: days,
            displayInterval: displayInterval,
            referenceNow: referenceNow,
            rhythmCalendar: calendar,
            metrics: metrics,
            pinIdentity: pinIdentity
        )
    }

    @ViewBuilder
    // swiftlint:disable:next function_parameter_count
    private func rhythmHistoryScrollSection(
        days: [ReviewDayActivity],
        displayInterval: Range<Date>,
        referenceNow: Date,
        rhythmCalendar: Calendar,
        metrics: RhythmCurveScaledMetrics,
        pinIdentity: ReviewRhythmScrollPinIdentity
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                rhythmChartStrip(days: days, metrics: metrics)
                rhythmLabelRow(
                    days: days,
                    displayInterval: displayInterval,
                    referenceNow: referenceNow,
                    rhythmCalendar: rhythmCalendar,
                    metrics: metrics
                )
            }
            .padding(.vertical, 8)
            .background(ReviewRhythmHorizontalScrollEndPin(pinIdentity: pinIdentity))
        }
        .rhythmHorizontalScrollUITestIdentifier()
        .frame(minHeight: metrics.horizontalScrollMinHeight)
        .overlay {
            rhythmHorizontalFeatherOverlay(daysCount: days.count, metrics: metrics)
        }
    }

    @ViewBuilder
    private func rhythmHorizontalFeatherOverlay(daysCount: Int, metrics: RhythmCurveScaledMetrics) -> some View {
        GeometryReader { geo in
            let estimatedContentWidth = metrics.estimatedContentWidth(daysCount: daysCount)
            if estimatedContentWidth > geo.size.width + 1 {
                let resolvedWidth = min(metrics.edgeFeatherWidth, geo.size.width * 0.45)
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [AppTheme.reviewPaper, AppTheme.reviewPaper.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: resolvedWidth)
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [AppTheme.reviewPaper.opacity(0), AppTheme.reviewPaper],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: resolvedWidth)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Per-day column with rounded fill; spaced from neighbors via ``RhythmCurveScaledMetrics/columnGap``.
    @ViewBuilder
    private func rhythmChartStrip(days: [ReviewDayActivity], metrics: RhythmCurveScaledMetrics) -> some View {
        HStack(alignment: .center, spacing: metrics.columnGap) {
            Color.clear
                .frame(width: metrics.chartHorizontalPadding)
                .accessibilityHidden(true)
            ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                rhythmColumnCell(
                    day: day,
                    index: index,
                    count: days.count,
                    metrics: metrics
                )
            }
            Color.clear
                .frame(width: metrics.chartHorizontalPadding)
                .accessibilityHidden(true)
        }
        .frame(minHeight: metrics.chartRowMinHeight)
    }

    @ViewBuilder
    private func rhythmColumnCell(
        day: ReviewDayActivity,
        index: Int,
        count: Int,
        metrics: RhythmCurveScaledMetrics
    ) -> some View {
        let cornerRadii = rhythmColumnCornerRadii(
            index: index,
            count: count,
            radius: metrics.columnCornerRadius
        )
        let column = rhythmColumnChart(day: day, metrics: metrics)
            .frame(width: metrics.columnWidth)
            .background {
                UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
                    .fill(AppTheme.reviewRhythmColumnFill)
            }
            .overlay {
                UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
                    .strokeBorder(AppTheme.reviewRhythmColumnStroke.opacity(0.58), lineWidth: 0.8)
            }

        Group {
            if day.hasPersistedEntry {
                if let onPersistedDaySelected {
                    Button {
                        onPersistedDaySelected(day.date)
                    } label: {
                        column
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        JournalScreen(entryDate: day.date)
                    } label: {
                        column
                    }
                    .buttonStyle(.plain)
                }
            } else {
                column
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activityAccessibilityLabel(for: day))
        .accessibilityHint(rhythmColumnAccessibilityHint(for: day))
        .accessibilityIdentifier(accessibilityRhythmColumnId(for: day))
        .id(day.date)
    }

    private func rhythmColumnAccessibilityHint(for day: ReviewDayActivity) -> String {
        if day.hasPersistedEntry {
            String(localized: "Opens the journal entry for that day.")
        } else {
            String(localized: "No saved journal entry for this day.")
        }
    }

    /// Weekday / M·d labels aligned under columns (below column fills).
    @ViewBuilder
    private func rhythmLabelRow(
        days: [ReviewDayActivity],
        displayInterval: Range<Date>,
        referenceNow: Date,
        rhythmCalendar: Calendar,
        metrics: RhythmCurveScaledMetrics
    ) -> some View {
        HStack(alignment: .top, spacing: metrics.columnGap) {
            Color.clear
                .frame(width: metrics.chartHorizontalPadding)
                .accessibilityHidden(true)
            ForEach(days, id: \.date) { day in
                rhythmColumnLabel(
                    date: day.date,
                    displayInterval: displayInterval,
                    referenceNow: referenceNow,
                    rhythmCalendar: rhythmCalendar
                )
                .frame(width: metrics.columnWidth)
            }
            Color.clear
                .frame(width: metrics.chartHorizontalPadding)
                .accessibilityHidden(true)
        }
    }

    private func rhythmColumnCornerRadii(
        index: Int,
        count: Int,
        radius: CGFloat
    ) -> RectangleCornerRadii {
        if count <= 1 {
            return RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: radius
            )
        }
        if index == 0 {
            return RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: 0,
                topTrailing: 0
            )
        }
        if index == count - 1 {
            return RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: 0,
                bottomTrailing: radius,
                topTrailing: radius
            )
        }
        return RectangleCornerRadii(
            topLeading: 0,
            bottomLeading: 0,
            bottomTrailing: 0,
            topTrailing: 0
        )
    }

    /// Five completion rows for one day; weekday labels sit in ``rhythmLabelRow``.
    private func rhythmColumnChart(day: ReviewDayActivity, metrics: RhythmCurveScaledMetrics) -> some View {
        let activeRow = levelRowIndexFromTop(for: day)
        return VStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { rowFromTop in
                ZStack {
                    if activeRow == rowFromTop {
                        rhythmStatusPill(for: day, metrics: metrics)
                    } else {
                        rhythmInactiveRowSlot()
                    }
                }
                .frame(height: metrics.rowHeight)
            }
        }
        .padding(.vertical, metrics.columnEdgeInset)
        .frame(minHeight: metrics.chartMinHeight)
    }

    private func rhythmInactiveRowSlot() -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    private func rhythmColumnLabel(
        date: Date,
        displayInterval: Range<Date>,
        referenceNow: Date,
        rhythmCalendar: Calendar
    ) -> some View {
        Text(
            ReviewRhythmFormatting.dayLabel(
                date: date,
                displayInterval: displayInterval,
                calendar: rhythmCalendar,
                referenceNow: referenceNow
            )
        )
        .monospacedDigit()
        .font(AppTheme.warmPaperCaption)
        .foregroundStyle(AppTheme.reviewTextMuted)
        .frame(maxWidth: .infinity)
        .lineLimit(2)
        .minimumScaleFactor(0.65)
        .multilineTextAlignment(.center)
    }

    private func rhythmStatusPill(for day: ReviewDayActivity, metrics: RhythmCurveScaledMetrics) -> some View {
        let level = effectiveCompletionLevel(for: day)
        return Image(ReviewRhythmFormatting.assetName(for: level))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppTheme.reviewRhythmIconTint)
            .frame(width: metrics.pillIconSize, height: metrics.pillIconSize)
            .frame(width: metrics.pillChromeSize, height: metrics.pillChromeSize)
            .background {
                Capsule(style: .continuous)
                    .fill(AppTheme.reviewRhythmPillBackground(for: level))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.reviewRhythmPillBorder(for: level), lineWidth: 1)
            }
            .shadow(color: AppTheme.reviewRhythmPillShadow(for: level), radius: 3, x: 0, y: 1.2)
            .accessibilityHidden(true)
    }

    private func effectiveCompletionLevel(for day: ReviewDayActivity) -> JournalCompletionLevel {
        day.strongestCompletionLevel ?? .soil
    }

    private func accessibilityRhythmColumnId(for day: ReviewDayActivity) -> String {
        // Integer seconds so UI tests and string catalog don’t depend on `Double` interpolation (`…1774540800.0`).
        "ReviewRhythmDay.\(Int(day.date.timeIntervalSince1970))"
    }

    private func levelRowIndexFromTop(for day: ReviewDayActivity) -> Int {
        let level = day.strongestCompletionLevel ?? .soil
        switch level {
        case .bloom:
            return 0
        case .leaf:
            return 1
        case .twig:
            return 2
        case .sprout:
            return 3
        case .soil:
            return 4
        }
    }

    private func localizedCompletionStageName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            String(localized: "Empty")
        case .sprout:
            String(localized: "Started")
        case .twig:
            String(localized: "Growing")
        case .leaf:
            String(localized: "Balanced")
        case .bloom:
            String(localized: "Full")
        }
    }

    private func activityAccessibilityLabel(for day: ReviewDayActivity) -> String {
        let dateText = day.date.formatted(date: .abbreviated, time: .omitted)
        if let level = day.strongestCompletionLevel {
            if level == .soil {
                return String(
                    format: String(localized: "You wrote on %@"),
                    dateText
                )
            }
            return String(
                format: String(localized: "You reached %1$@ on %2$@."),
                localizedCompletionStageName(for: level),
                dateText
            )
        }
        if day.hasReflectiveActivity {
            return String(
                format: String(localized: "You wrote on %@"),
                dateText
            )
        }
        return String(
            format: String(localized: "No writing on %@"),
            dateText
        )
    }

    /// Layout metrics for the reflection rhythm chart, scaled for Dynamic Type.
    private struct RhythmCurveScaledMetrics {
        let columnWidth: CGFloat
        let columnGap: CGFloat
        let columnCornerRadius: CGFloat
        let columnEdgeInset: CGFloat
        let rowHeight: CGFloat
        let chartMinHeight: CGFloat
        let chartRowMinHeight: CGFloat
        let pillIconSize: CGFloat
        let pillChromeSize: CGFloat
        let edgeFeatherWidth: CGFloat
        let chartHorizontalPadding: CGFloat

        init(dynamicTypeSize: DynamicTypeSize) {
            let scale = Self.scale(for: dynamicTypeSize)
            columnWidth = (64 * scale).rounded(.toNearestOrAwayFromZero)
            columnGap = max(2, (3 * scale).rounded(.toNearestOrAwayFromZero))
            columnCornerRadius = (10 * scale).rounded(.toNearestOrAwayFromZero)
            columnEdgeInset = max(2, (3 * scale).rounded(.toNearestOrAwayFromZero))
            rowHeight = (34 * scale).rounded(.toNearestOrAwayFromZero)
            chartMinHeight = (150 * scale).rounded(.toNearestOrAwayFromZero)
            let innerRowSpacing: CGFloat = 3
            let innerStackHeight = 5 * rowHeight + 4 * innerRowSpacing
            chartRowMinHeight = max(innerStackHeight + (2 * columnEdgeInset), chartMinHeight)
            pillIconSize = (15 * scale).rounded(.toNearestOrAwayFromZero)
            pillChromeSize = (28 * scale).rounded(.toNearestOrAwayFromZero)
            edgeFeatherWidth = max(10, (14 * scale).rounded(.toNearestOrAwayFromZero))
            chartHorizontalPadding = max(10, (14 * scale).rounded(.toNearestOrAwayFromZero))
        }

        /// Chart columns + label row + ``ScrollView`` vertical padding.
        var horizontalScrollMinHeight: CGFloat {
            let labelRowSpacing: CGFloat = 6
            let labelRowHeight = max(22, rowHeight * 0.72)
            let lazyStackVerticalPadding: CGFloat = 16
            return chartRowMinHeight + labelRowSpacing + labelRowHeight + lazyStackVerticalPadding
        }

        func estimatedContentWidth(daysCount: Int) -> CGFloat {
            guard daysCount > 0 else { return 2 * chartHorizontalPadding }
            let columns = CGFloat(daysCount) * columnWidth
            let gaps = CGFloat(max(0, daysCount - 1)) * columnGap
            return columns + gaps + (2 * chartHorizontalPadding)
        }

        // swiftlint:disable:next cyclomatic_complexity
        private static func scale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
            switch dynamicTypeSize {
            case .xSmall:
                return 0.9
            case .small:
                return 0.94
            case .medium, .large:
                return 1.0
            case .xLarge:
                return 1.05
            case .xxLarge:
                return 1.1
            case .xxxLarge:
                return 1.15
            case .accessibility1:
                return 1.18
            case .accessibility2:
                return 1.24
            case .accessibility3:
                return 1.3
            case .accessibility4:
                return 1.36
            case .accessibility5:
                return 1.42
            @unknown default:
                return 1.2
            }
        }
    }
}

/// Observation, next step, and primary CTA for the Past tab as its own list row (after recurring and trending).
struct ReviewNarrativeSummaryCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let insights: ReviewInsights?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let insights {
                narrativeContentWithLoadingAccessibility(for: insights)
            } else if isLoading {
                NarrativeInsightsLoadingSkeleton(reduceMotion: reduceMotion)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "Start writing this week to unlock review insights."))
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func narrativeContentWithLoadingAccessibility(for insights: ReviewInsights) -> some View {
        if isLoading {
            narrativeContent(for: insights)
                .accessibilityHint(String(localized: "Updated insights appear when ready."))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            narrativeContent(for: insights)
        }
    }

    private func narrativeContent(for insights: ReviewInsights) -> some View {
        let bodies = dedupedPanelBodies(for: insights)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                observationPanel(body: bodies.observation)
                // Intentional product choice: keep the middle "Thinking"/narrative layer hidden for now.
                if insights.presentationMode == .insight {
                    // `.statsFirst` stays rhythm-led by design, so we omit the next-step panel in that mode.
                    actionPanel(body: bodies.action)
                }
            }
        }
    }

    private func observationPanel(body: String) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Observation"),
            panelChrome: .lead
        ) {
            panelParagraph(body, lineSpacing: 4)
        }
    }

    private func actionPanel(body: String) -> some View {
        ReviewInsightInsetPanel(title: String(localized: "A next step"), panelChrome: .standard) {
            panelParagraph(body, lineSpacing: 4)
        }
    }

    private func panelParagraph(_ text: String, lineSpacing: CGFloat) -> some View {
        Text(trimmed(text))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.reviewTextPrimary)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
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

    private func observationText(for insights: ReviewInsights) -> String {
        let resurfacing = trimmed(insights.resurfacingMessage)
        if !resurfacing.isEmpty {
            return resurfacing
        }
        if let fallbackObservation = firstNonEmptyWeeklyObservation(for: insights) {
            return fallbackObservation
        }
        let fallbackNarrative = trimmed(insights.narrativeSummary)
        if !fallbackNarrative.isEmpty {
            return fallbackNarrative
        }
        return trimmed(insights.continuityPrompt)
    }

    private func thinkingText(for insights: ReviewInsights) -> String {
        let narrativeSummary = trimmed(insights.narrativeSummary)
        if shouldShowNarrativeSummary(for: insights), !narrativeSummary.isEmpty {
            return narrativeSummary
        }
        if let fallbackObservation = firstNonEmptyWeeklyObservation(for: insights) {
            return fallbackObservation
        }
        let resurfacing = trimmed(insights.resurfacingMessage)
        if !resurfacing.isEmpty {
            return resurfacing
        }
        return trimmed(insights.continuityPrompt)
    }

    /// Action line from payload only (no Thinking fallback) so the card can substitute a distinct thin-week string.
    private func actionBodyCandidate(for insights: ReviewInsights) -> String {
        let continuityPrompt = trimmed(insights.continuityPrompt)
        if !continuityPrompt.isEmpty {
            return continuityPrompt
        }
        if let fallbackAction = firstNonEmptyWeeklyAction(for: insights) {
            return fallbackAction
        }
        return ""
    }

    private func dedupedPanelBodies(for insights: ReviewInsights) -> ReviewInsightPanelBodies {
        let observation = observationText(for: insights)
        var thread = thinkingText(for: insights)
        if normalizedInsightText(thread) == normalizedInsightText(observation) {
            thread = String(localized: "When you're ready, a few lines can still hold a lot.")
        }

        var action = actionBodyCandidate(for: insights)
        let observationKey = normalizedInsightText(observation)
        let actionKey = normalizedInsightText(action)
        // Action dedupes against visible panels only; Thinking is intentionally hidden in this layout.
        let actionDuplicatesPanel = actionKey == observationKey
        if action.isEmpty || actionDuplicatesPanel {
            action = String(localized: "What's one thing you're glad happened, even if small?")
        }

        return ReviewInsightPanelBodies(observation: observation, thread: thread, action: action)
    }

    private func firstNonEmptyWeeklyObservation(for insights: ReviewInsights) -> String? {
        insights.weeklyInsights
            .lazy
            .map(\.observation)
            .map { trimmed($0) }
            .first { !$0.isEmpty }
    }

    private func firstNonEmptyWeeklyAction(for insights: ReviewInsights) -> String? {
        insights.weeklyInsights
            .lazy
            .compactMap(\.action)
            .map { trimmed($0) }
            .first { !$0.isEmpty }
    }

    private func trimmed(_ value: String?) -> String {
        guard let value else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedInsightText(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
// swiftlint:enable type_body_length

private struct RhythmLoadingSkeleton: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            skeletonInsetPanel(
                title: String(localized: "Reflection rhythm"),
                panelChrome: .standard,
                lineSpecs: [(1.0, 10), (0.64, 10)]
            )
        }
        .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading weekly insights."))
    }

    private func skeletonInsetPanel(
        title: String,
        panelChrome: ReviewInsightPanelChrome,
        lineSpecs: [(CGFloat, CGFloat)]
    ) -> some View {
        ReviewInsightInsetPanel(title: title, panelChrome: panelChrome) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lineSpecs.enumerated()), id: \.offset) { _, spec in
                    InsightsPlaceholderBar(widthFraction: spec.0, height: spec.1)
                }
            }
        }
    }
}

private struct NarrativeInsightsLoadingSkeleton: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                skeletonInsetPanel(
                    title: String(localized: "Observation"),
                    panelChrome: .lead,
                    lineSpecs: [(1.0, 12), (1.0, 12), (0.72, 12)]
                )
                skeletonInsetPanel(
                    title: String(localized: "A next step"),
                    panelChrome: .standard,
                    lineSpecs: [(1.0, 11), (0.78, 11)]
                )
            }
        }
        .modifier(InsightsCalmLoadingBreath(active: !reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading weekly insights."))
    }

    private func skeletonInsetPanel(
        title: String,
        panelChrome: ReviewInsightPanelChrome,
        lineSpecs: [(CGFloat, CGFloat)]
    ) -> some View {
        ReviewInsightInsetPanel(title: title, panelChrome: panelChrome) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lineSpecs.enumerated()), id: \.offset) { _, spec in
                    InsightsPlaceholderBar(widthFraction: spec.0, height: spec.1)
                }
            }
        }
    }
}

/// Pins the backing `UIScrollView` to the trailing edge when content is wider than the viewport (issue #127).
/// `ScrollViewReader` / `GeometryReader` on scroll content can run before layout or break intrinsic width.
private struct ReviewRhythmHorizontalScrollEndPin: UIViewRepresentable {
    var pinIdentity: ReviewRhythmScrollPinIdentity

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = ReviewRhythmScrollLayoutProbeView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.probeView = view
        view.onLayout = { [weak coordinator = context.coordinator] in
            coordinator?.attachIfNeeded()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.syncPinIdentity(pinIdentity)
        context.coordinator.attachIfNeeded()
    }

    final class Coordinator {
        weak var probeView: UIView?
        weak var observedScrollView: UIScrollView?
        var contentSizeObservation: NSKeyValueObservation?
        var boundsObservation: NSKeyValueObservation?
        var contentOffsetObservation: NSKeyValueObservation?
        private var appliedPinIdentity: ReviewRhythmScrollPinIdentity?
        private var userDidAdjustHorizontalScroll = false

        deinit {
            contentSizeObservation = nil
            boundsObservation = nil
            contentOffsetObservation = nil
        }

        func syncPinIdentity(_ newIdentity: ReviewRhythmScrollPinIdentity) {
            if appliedPinIdentity != newIdentity {
                appliedPinIdentity = newIdentity
                userDidAdjustHorizontalScroll = false
            }
        }

        func attachIfNeeded() {
            guard let probeView else { return }
            guard let scrollView = findAncestorScrollView(from: probeView) else { return }
            if observedScrollView === scrollView {
                pinToTrailingIfNeeded(scrollView)
                return
            }
            contentSizeObservation = nil
            boundsObservation = nil
            contentOffsetObservation = nil
            observedScrollView = scrollView
            contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                guard let self, let observed = self.observedScrollView else { return }
                self.pinToTrailingIfNeeded(observed)
            }
            boundsObservation = scrollView.observe(\.bounds, options: [.new]) { [weak self] _, _ in
                guard let self, let observed = self.observedScrollView else { return }
                self.pinToTrailingIfNeeded(observed)
            }
            contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] observed, _ in
                guard let self else { return }
                if observed.isDragging || observed.isDecelerating {
                    self.userDidAdjustHorizontalScroll = true
                }
            }
            pinToTrailingIfNeeded(scrollView)
        }

        private func pinToTrailingIfNeeded(_ scrollView: UIScrollView) {
            guard !userDidAdjustHorizontalScroll else { return }
            let contentWidth = scrollView.contentSize.width
            let viewportWidth = scrollView.bounds.width
            guard contentWidth > viewportWidth + 0.5 else { return }
            guard scrollView.contentOffset.x < 8 else { return }
            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                guard !self.userDidAdjustHorizontalScroll else { return }
                let contentWidth = scrollView.contentSize.width
                let viewportWidth = scrollView.bounds.width
                guard contentWidth > viewportWidth + 0.5 else { return }
                let target = max(0, contentWidth - viewportWidth)
                scrollView.setContentOffset(CGPoint(x: target, y: scrollView.contentOffset.y), animated: false)
            }
        }

        private func findAncestorScrollView(from view: UIView) -> UIScrollView? {
            var currentView: UIView? = view
            while let candidate = currentView?.superview {
                if let scrollView = candidate as? UIScrollView {
                    return scrollView
                }
                currentView = candidate
            }
            return nil
        }
    }
}

private final class ReviewRhythmScrollLayoutProbeView: UIView {
    var onLayout: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onLayout?()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        onLayout?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

private extension View {
    @ViewBuilder
    func rhythmHorizontalScrollUITestIdentifier() -> some View {
        if ProcessInfo.graceNotesIsRunningUITests {
            accessibilityIdentifier("ReviewRhythmHorizontalScroll")
        } else {
            self
        }
    }
}

// swiftlint:enable file_length
