import SwiftUI
import UIKit

private struct ReviewInsightPanelBodies {
    let observation: String
    let thread: String
    let action: String
}

// swiftlint:disable type_body_length file_length
struct ReviewSummaryCard: View {
    /// Hide the “Write today’s reflection” nudge under loaded insights when the review week has at least this
    /// many journal entries. UI-only; not cloud eligibility.
    private static let minWeekEntriesToOmitContinueNudge = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue
    @State private var selectedThemeDrilldown: ReviewThemeDrilldownPayload?
    @State private var mostRecurringBrowsePayload: MostRecurringBrowsePayload?
    @State private var trendingBrowsePayload: TrendingBrowsePayload?

    let insights: ReviewInsights?
    let isLoading: Bool
    let weekJournalEntryCount: Int
    let onContinueToToday: () -> Void

    private var reviewCalendar: Calendar {
        ReviewWeekBoundaryPreference.resolve(from: reviewWeekBoundaryRawValue).configuredCalendar()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let insights {
                insightsContentWithLoadingAccessibility(for: insights)
            } else if isLoading {
                InsightsLoadingSkeleton(reduceMotion: reduceMotion)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "Start writing this week to unlock review insights."))
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                    continueJournalCallToAction()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .sheet(item: $selectedThemeDrilldown) { payload in
            ThemeDrilldownSheet(payload: payload)
        }
        .sheet(item: $mostRecurringBrowsePayload) { payload in
            MostRecurringBrowseSheetContainer(
                themes: payload.themes,
                reviewWeekEnd: payload.reviewWeekEnd,
                calendar: payload.calendar
            )
        }
        .sheet(item: $trendingBrowsePayload) { payload in
            TrendingBrowseSheetContainer(buckets: payload.buckets)
        }
    }

    @ViewBuilder
    private func insightsContentWithLoadingAccessibility(for insights: ReviewInsights) -> some View {
        if isLoading {
            insightsContent(for: insights)
                .accessibilityHint(String(localized: "Updated insights appear when ready."))
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            insightsContent(for: insights)
        }
    }

    private func insightsContent(for insights: ReviewInsights) -> some View {
        let bodies = dedupedPanelBodies(for: insights)
        let mostRecurringThemes = insights.weekStats.mostRecurringThemes
        let trendingBuckets = insights.weekStats.trendingBuckets
        let movementThemes = insights.weekStats.movementThemes
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                weekRhythmPanel(for: insights)
                if !mostRecurringThemes.isEmpty {
                    mostRecurringThemesPanel(
                        themes: mostRecurringThemes,
                        reviewWeekEnd: insights.weekEnd,
                        calendar: reviewCalendar
                    )
                }
                if !movementThemes.isEmpty {
                    trendingThemesPanel(buckets: trendingBuckets)
                }
                observationPanel(body: bodies.observation)
                // Intentional product choice: keep the middle "Thinking"/narrative layer hidden for now.
                if insights.presentationMode == .insight {
                    // `.statsFirst` stays rhythm-led by design, so we omit the next-step panel in that mode.
                    actionPanel(body: bodies.action)
                }
                if weekJournalEntryCount < Self.minWeekEntriesToOmitContinueNudge {
                    continueJournalCallToAction()
                }
            }
        }
    }

    @ViewBuilder
    private func continueJournalCallToAction() -> some View {
        Button(action: onContinueToToday) {
            Text(String(localized: "Write today's reflection"))
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.reviewOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.reviewAccent.opacity(0.32))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityIdentifier("ReviewInsightsContinueJournalCTA")
    }

    private func observationPanel(body: String) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Observation"),
            panelChrome: .lead
        ) {
            panelParagraph(body, lineSpacing: 4)
        }
    }

    private func thinkingPanel(body: String) -> some View {
        ReviewInsightInsetPanel(title: String(localized: "This week's theme"), panelChrome: .standard) {
            panelParagraph(body, lineSpacing: 4)
        }
    }

    private func actionPanel(body: String) -> some View {
        ReviewInsightInsetPanel(title: String(localized: "A next step"), panelChrome: .standard) {
            panelParagraph(body, lineSpacing: 4)
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

    private func mostRecurringThemesPanel(
        themes: [ReviewMostRecurringTheme],
        reviewWeekEnd: Date,
        calendar: Calendar
    ) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Most recurring"),
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
                        mostRecurringBrowsePayload = MostRecurringBrowsePayload(
                            themes: themes,
                            reviewWeekEnd: reviewWeekEnd,
                            calendar: calendar
                        )
                    } label: {
                        browseAllLabel(title: String(localized: "Browse all recurring themes"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("BrowseAllRecurringThemesLink")
                }
            }
        }
    }

    private func mostRecurringThemeRow(_ theme: ReviewMostRecurringTheme) -> some View {
        Button {
            selectedThemeDrilldown = drilldownPayload(for: theme)
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("MostRecurringThemeRow.\(sanitizedThemeId(theme.id))")
        .accessibilityLabel(
            String(
                format: String(localized: "%1$@, %2$@, %3$lld"),
                theme.label,
                String(localized: "Count"),
                Int64(theme.totalCount)
            )
        )
    }

    private func trendingThemesPanel(buckets: ReviewTrendingBuckets) -> some View {
        let themes = buckets.flattened
        return ReviewInsightInsetPanel(
            title: String(localized: "Trending"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(themes.prefix(3))) { theme in
                        trendingThemeRow(theme)
                    }
                }
                if themes.count > 3 {
                    Button {
                        trendingBrowsePayload = TrendingBrowsePayload(buckets: buckets)
                    } label: {
                        browseAllLabel(title: String(localized: "Browse all trending themes"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("BrowseAllTrendingThemesLink")
                }
            }
        }
    }

    private func trendingThemeRow(_ theme: ReviewMovementTheme) -> some View {
        Button {
            selectedThemeDrilldown = drilldownPayload(for: theme)
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
                    previous: theme.previousWeekCount,
                    current: theme.currentWeekCount,
                    accent: trendColor(theme.trend)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("TrendingThemeRow.\(sanitizedThemeId(theme.id))")
        .accessibilityLabel(
            String(
                format: String(localized: "%1$@, %2$@, %3$lld, %4$lld"),
                theme.label,
                localizedTrendLabel(theme.trend),
                Int64(theme.previousWeekCount),
                Int64(theme.currentWeekCount)
            )
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

    private func drilldownPayload(for theme: ReviewMostRecurringTheme) -> ReviewThemeDrilldownPayload {
        ReviewThemeDrilldownPayload(
            label: theme.label,
            sectionTitle: String(localized: "Most recurring"),
            subtitle: String(
                format: String(localized: "Showed up %1$lld times in the last 4 weeks."),
                Int64(theme.totalCount)
            ),
            trend: nil,
            evidence: theme.evidence
        )
    }

    private func drilldownPayload(for theme: ReviewMovementTheme) -> ReviewThemeDrilldownPayload {
        let trendText = localizedTrendLabel(theme.trend)
        let subtitle = String(
            format: String(
                localized: "Last 7 days %1$lld, prior 7 days %2$lld."
            ),
            Int64(theme.currentWeekCount),
            Int64(theme.previousWeekCount)
        )
        return ReviewThemeDrilldownPayload(
            label: theme.label,
            sectionTitle: String(localized: "Trending"),
            subtitle: "\(trendText). \(subtitle)",
            trend: theme.trend,
            evidence: theme.evidence
        )
    }

    private func sanitizedThemeId(_ value: String) -> String {
        let cleaned = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if cleaned.isEmpty {
            return "theme"
        }
        return cleaned
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

    private func localizedTrendLabel(_ trend: ReviewThemeTrend) -> String {
        switch trend {
        case .new:
            return String(localized: "New")
        case .rising:
            return String(localized: "Up")
        case .down:
            return String(localized: "Down")
        case .stable:
            return String(localized: "Stable")
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

    private func rhythmHistoryCurve(for insights: ReviewInsights) -> some View {
        let stats = insights.weekStats
        let days = stats.rhythmHistory ?? stats.activity
        let currentWeek = insights.weekStart..<insights.weekEnd
        let metrics = RhythmCurveScaledMetrics(dynamicTypeSize: dynamicTypeSize)
        let pinIdentity = ReviewRhythmScrollPinIdentity(weekStart: insights.weekStart, days: days)
        return rhythmHistoryScrollSection(
            days: days,
            currentWeek: currentWeek,
            metrics: metrics,
            pinIdentity: pinIdentity
        )
    }

    @ViewBuilder
    private func rhythmHistoryScrollSection(
        days: [ReviewDayActivity],
        currentWeek: Range<Date>,
        metrics: RhythmCurveScaledMetrics,
        pinIdentity: ReviewRhythmScrollPinIdentity
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                rhythmChartStrip(days: days, metrics: metrics)
                rhythmLabelRow(
                    days: days,
                    currentWeek: currentWeek,
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
                    .stroke(AppTheme.reviewRhythmColumnStroke.opacity(0.58), lineWidth: 0.8)
            }

        Group {
            if day.hasPersistedEntry {
                NavigationLink {
                    JournalScreen(entryDate: day.date)
                } label: {
                    column
                }
                .buttonStyle(.plain)
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
        currentWeek: Range<Date>,
        metrics: RhythmCurveScaledMetrics
    ) -> some View {
        HStack(alignment: .top, spacing: metrics.columnGap) {
            Color.clear
                .frame(width: metrics.chartHorizontalPadding)
                .accessibilityHidden(true)
            ForEach(days, id: \.date) { day in
                rhythmColumnLabel(
                    date: day.date,
                    currentWeek: currentWeek
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
        currentWeek: Range<Date>
    ) -> some View {
        Text(ReviewRhythmFormatting.dayLabel(date: date, currentWeek: currentWeek, calendar: .current))
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
                    .stroke(AppTheme.reviewRhythmPillBorder(for: level), lineWidth: 1)
            }
            .shadow(color: AppTheme.reviewRhythmPillShadow(for: level), radius: 3, x: 0, y: 1.2)
            .accessibilityHidden(true)
    }

    private func effectiveCompletionLevel(for day: ReviewDayActivity) -> JournalCompletionLevel {
        day.strongestCompletionLevel ?? .empty
    }

    private func accessibilityRhythmColumnId(for day: ReviewDayActivity) -> String {
        // Integer seconds so UI tests and string catalog don’t depend on `Double` interpolation (`…1774540800.0`).
        "ReviewRhythmDay.\(Int(day.date.timeIntervalSince1970))"
    }

    private func levelRowIndexFromTop(for day: ReviewDayActivity) -> Int {
        let level = day.strongestCompletionLevel ?? .empty
        switch level {
        case .full:
            return 0
        case .balanced:
            return 1
        case .growing:
            return 2
        case .started:
            return 3
        case .empty:
            return 4
        }
    }

    private func localizedCompletionStageName(for level: JournalCompletionLevel) -> String {
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

    private func activityAccessibilityLabel(for day: ReviewDayActivity) -> String {
        let dateText = day.date.formatted(date: .abbreviated, time: .omitted)
        if let level = day.strongestCompletionLevel {
            if level == .empty {
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
// swiftlint:enable type_body_length

private struct InsightsLoadingSkeleton: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                skeletonInsetPanel(
                    title: String(localized: "Reflection rhythm"),
                    panelChrome: .standard,
                    lineSpecs: [(1.0, 10), (0.64, 10)]
                )
                skeletonInsetPanel(
                    title: String(localized: "Most recurring"),
                    panelChrome: .standard,
                    lineSpecs: [(1.0, 11), (0.78, 11), (0.66, 11)]
                )
                skeletonInsetPanel(
                    title: String(localized: "Trending"),
                    panelChrome: .standard,
                    lineSpecs: [(1.0, 11), (0.82, 11), (0.7, 11)]
                )
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

/// Soft, static bars — motion (if any) comes from ``InsightsCalmLoadingBreath`` on the whole skeleton.
private struct InsightsPlaceholderBar: View {
    var widthFraction: CGFloat = 1.0
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let lineWidth = max(geo.size.width * widthFraction, height * 2)
            RoundedRectangle(cornerRadius: height * 0.42, style: .continuous)
                .fill(AppTheme.reviewTextMuted.opacity(0.10))
                .frame(width: lineWidth, height: height, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Very slow, low-contrast breathing — no traveling highlight.
private struct InsightsCalmLoadingBreath: ViewModifier {
    let active: Bool
    /// Seconds per full cycle; larger is calmer.
    private var period: Double { 5.5 }
    /// Half the peak-to-trough opacity swing (sin ∈ [-1, 1], so total swing is 2× this).
    private var opacitySwing: Double { 0.028 }

    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation(minimumInterval: 0.4, paused: false)) { context in
                let seconds = context.date.timeIntervalSinceReferenceDate
                let wave = sin(seconds * 2 * .pi / period)
                let opacity = 0.965 + opacitySwing * wave
                content.opacity(opacity)
            }
        } else {
            content.opacity(0.97)
        }
    }
}

private struct ReviewTrendBadge: View {
    let trend: ReviewThemeTrend

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var symbol: String {
        switch trend {
        case .new:
            return "sparkles"
        case .rising:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .stable:
            return "equal"
        }
    }

    private var backgroundColor: Color {
        switch trend {
        case .new:
            return .blue.opacity(0.15)
        case .rising:
            return .green.opacity(0.16)
        case .down:
            return .orange.opacity(0.16)
        case .stable:
            return AppTheme.reviewStandardBorder.opacity(0.22)
        }
    }

    private var foregroundColor: Color {
        switch trend {
        case .new:
            return .blue
        case .rising:
            return .green
        case .down:
            return .orange
        case .stable:
            return AppTheme.reviewTextPrimary
        }
    }

    private var label: String {
        switch trend {
        case .new:
            return String(localized: "New")
        case .rising:
            return String(localized: "Up")
        case .down:
            return String(localized: "Down")
        case .stable:
            return String(localized: "Stable")
        }
    }
}

/// Compact `previous → current` counts for rolling 7-day trending rows.
private struct ReviewTrendCountCapsule: View {
    let previous: Int
    let current: Int
    let accent: Color

    var body: some View {
        Text(
            String(
                format: String(localized: "%1$lld → %2$lld"),
                Int64(previous),
                Int64(current)
            )
        )
        .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
        .foregroundStyle(AppTheme.reviewTextPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(accent.opacity(0.16))
        .clipShape(Capsule())
    }
}

private struct ReviewThemeDrilldownPayload: Identifiable {
    let label: String
    let sectionTitle: String
    let subtitle: String
    let trend: ReviewThemeTrend?
    let evidence: [ReviewThemeSurfaceEvidence]

    var id: String {
        "\(sectionTitle)|\(label)"
    }
}

private struct MostRecurringBrowsePayload: Identifiable {
    let id = UUID()
    let themes: [ReviewMostRecurringTheme]
    let reviewWeekEnd: Date
    let calendar: Calendar
}

private struct TrendingBrowsePayload: Identifiable {
    let id = UUID()
    let buckets: ReviewTrendingBuckets
}

private struct MostRecurringBrowseSheetContainer: View {
    let themes: [ReviewMostRecurringTheme]
    let reviewWeekEnd: Date
    let calendar: Calendar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MostRecurringThemesBrowseView(themes: themes, reviewWeekEnd: reviewWeekEnd, calendar: calendar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                        .accessibilityIdentifier("MostRecurringBrowseSheetDone")
                    }
                }
        }
    }
}

private struct TrendingBrowseSheetContainer: View {
    let buckets: ReviewTrendingBuckets
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TrendingThemesBrowseView(buckets: buckets)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                        .accessibilityIdentifier("TrendingBrowseSheetDone")
                    }
                }
        }
    }
}

private struct MostRecurringThemesBrowseView: View {
    let themes: [ReviewMostRecurringTheme]
    let reviewWeekEnd: Date
    let calendar: Calendar
    @State private var viewingWindow: MostRecurringBrowseWindow = .fourWeeks

    var body: some View {
        List {
            Section {
                Picker(String(localized: "Viewing window"), selection: $viewingWindow) {
                    ForEach(MostRecurringBrowseWindow.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("MostRecurringBrowseWindowPicker")
            }

            if !gratitudeRows.isEmpty {
                recurringSection(
                    section: .gratitudes,
                    title: String(localized: "Gratitudes"),
                    rows: gratitudeRows
                )
            }
            if !needsRows.isEmpty {
                recurringSection(
                    section: .needs,
                    title: String(localized: "Needs"),
                    rows: needsRows
                )
            }
            if !peopleRows.isEmpty {
                recurringSection(
                    section: .people,
                    title: String(localized: "People in Mind"),
                    rows: peopleRows
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .navigationTitle(String(localized: "Most recurring"))
    }

    private func recurringSection(
        section: ReviewThemeSourceCategory,
        title: String,
        rows: [MostRecurringBrowseRowModel]
    ) -> some View {
        Section {
            ForEach(rows) { row in
                NavigationLink {
                    ThemeDrilldownView(
                        payload: drilldownPayload(for: row),
                        includeDoneButton: false
                    )
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Text(row.label)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        ReviewCountBadge(
                            value: row.mentionCount.formatted(),
                            accent: AppTheme.reviewAccent
                        )
                    }
                }
                .accessibilityIdentifier("MostRecurringThemeBrowseRow.\(row.accessibilityId)")
            }
        } header: {
            Text(title)
                .textCase(nil)
                .accessibilityIdentifier("MostRecurringBrowseSection.\(section.rawValue)")
        }
    }

    private var viewingDateRange: Range<Date> {
        let daysBack = viewingWindow.weeks * 7
        let rawLower = calendar.date(byAdding: .day, value: -daysBack, to: reviewWeekEnd) ?? reviewWeekEnd
        let lowerBound = calendar.startOfDay(for: rawLower)
        return lowerBound..<reviewWeekEnd
    }

    private var gratitudeRows: [MostRecurringBrowseRowModel] {
        rows(for: .gratitudes)
    }

    private var needsRows: [MostRecurringBrowseRowModel] {
        rows(for: .needs)
    }

    private var peopleRows: [MostRecurringBrowseRowModel] {
        rows(for: .people)
    }

    private func rows(for section: ReviewThemeSourceCategory) -> [MostRecurringBrowseRowModel] {
        themes.compactMap { theme in
            let windowed = theme.evidence.filter { evidence in
                evidence.source == section
                    && viewingDateRange.contains(calendar.startOfDay(for: evidence.entryDate))
            }
            guard !windowed.isEmpty else { return nil }
            let sortedEvidence = windowed.sorted { lhs, rhs in
                if lhs.entryDate != rhs.entryDate {
                    return lhs.entryDate > rhs.entryDate
                }
                return lhs.content.localizedCaseInsensitiveCompare(rhs.content) == .orderedAscending
            }
            return MostRecurringBrowseRowModel(
                label: theme.label,
                themeId: theme.id,
                section: section,
                mentionCount: windowed.count,
                evidence: sortedEvidence
            )
        }
        .sorted {
            if $0.mentionCount != $1.mentionCount {
                return $0.mentionCount > $1.mentionCount
            }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    private func drilldownPayload(for row: MostRecurringBrowseRowModel) -> ReviewThemeDrilldownPayload {
        ReviewThemeDrilldownPayload(
            label: row.label,
            sectionTitle: String(localized: "Most recurring"),
            subtitle: String(
                format: String(localized: "Showed up %1$lld times in the last %2$lld weeks."),
                Int64(row.mentionCount),
                Int64(viewingWindow.weeks)
            ),
            trend: nil,
            evidence: row.evidence
        )
    }
}

private struct MostRecurringBrowseRowModel: Identifiable {
    let label: String
    let themeId: String
    let section: ReviewThemeSourceCategory
    let mentionCount: Int
    let evidence: [ReviewThemeSurfaceEvidence]

    var id: String { "\(themeId)|\(section.rawValue)" }

    var accessibilityId: String {
        "\(sanitizedThemeId(themeId)).\(section.rawValue)"
    }

    private func sanitizedThemeId(_ value: String) -> String {
        let cleaned = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if cleaned.isEmpty {
            return "theme"
        }
        return cleaned
    }
}

private enum MostRecurringBrowseWindow: Int, CaseIterable, Identifiable {
    case twoWeeks = 2
    case fourWeeks = 4
    case eightWeeks = 8

    var id: Int { rawValue }

    var weeks: Int { rawValue }

    var title: String {
        switch self {
        case .twoWeeks:
            return String(localized: "2 weeks")
        case .fourWeeks:
            return String(localized: "4 weeks")
        case .eightWeeks:
            return String(localized: "8 weeks")
        }
    }
}

private struct TrendingThemesBrowseView: View {
    let buckets: ReviewTrendingBuckets

    var body: some View {
        List {
            if !buckets.newThemes.isEmpty {
                trendingSection(title: String(localized: "New"), themes: buckets.newThemes)
            }
            if !buckets.upThemes.isEmpty {
                trendingSection(title: String(localized: "Up"), themes: buckets.upThemes)
            }
            if !buckets.downThemes.isEmpty {
                trendingSection(title: String(localized: "Down"), themes: buckets.downThemes)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .navigationTitle(String(localized: "Trending"))
    }

    private func trendingSection(title: String, themes: [ReviewMovementTheme]) -> some View {
        Section {
            ForEach(themes) { theme in
                NavigationLink {
                    ThemeDrilldownView(payload: drilldownPayload(for: theme), includeDoneButton: false)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Text(theme.label)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        ReviewTrendBadge(trend: theme.trend)
                        ReviewTrendCountCapsule(
                            previous: theme.previousWeekCount,
                            current: theme.currentWeekCount,
                            accent: movementAccent(theme.trend)
                        )
                    }
                }
                .accessibilityIdentifier("TrendingThemeBrowseRow.\(theme.id)")
            }
        } header: {
            Text(title)
                .textCase(nil)
        }
    }

    private func movementAccent(_ trend: ReviewThemeTrend) -> Color {
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

    private func drilldownPayload(for theme: ReviewMovementTheme) -> ReviewThemeDrilldownPayload {
        ReviewThemeDrilldownPayload(
            label: theme.label,
            sectionTitle: String(localized: "Trending"),
            subtitle: String(
                format: String(localized: "Last 7 days %1$lld, prior 7 days %2$lld."),
                Int64(theme.currentWeekCount),
                Int64(theme.previousWeekCount)
            ),
            trend: theme.trend,
            evidence: theme.evidence
        )
    }
}

private struct ThemeDrilldownSheet: View {
    let payload: ReviewThemeDrilldownPayload

    var body: some View {
        ThemeDrilldownView(payload: payload, includeDoneButton: true)
    }
}

private struct ThemeDrilldownView: View {
    let payload: ReviewThemeDrilldownPayload
    let includeDoneButton: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.label)
                            .font(AppTheme.warmPaperHeader)
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .accessibilityIdentifier("ThemeDrilldownTitle")
                        if let trend = payload.trend {
                            ReviewTrendBadge(trend: trend)
                        }
                        Text(payload.subtitle)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text(String(localized: "Summary"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                }

                Section {
                    ForEach(payload.evidence) { evidence in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(localizedSourceLabel(evidence.source))
                                    .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                                    .foregroundStyle(AppTheme.reviewTextPrimary)
                                Spacer(minLength: 6)
                                Text(evidence.entryDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(AppTheme.warmPaperMeta)
                                    .foregroundStyle(AppTheme.reviewTextMuted)
                            }
                            Text(evidence.content)
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            NavigationLink {
                                JournalScreen(entryDate: evidence.entryDate)
                            } label: {
                                Text(String(localized: "Open journal entry"))
                                    .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                                    .foregroundStyle(AppTheme.reviewAccent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(String(localized: "Matching writing surfaces"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.reviewBackground)
            .navigationTitle(String(localized: "Theme details"))
            .toolbar {
                if includeDoneButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func localizedSourceLabel(_ source: ReviewThemeSourceCategory) -> String {
        switch source {
        case .gratitudes:
            return String(localized: "Gratitudes")
        case .needs:
            return String(localized: "Needs")
        case .people:
            return String(localized: "People in Mind")
        case .readingNotes:
            return String(localized: "Reading notes")
        case .reflections:
            return String(localized: "Reflections")
        }
    }
}

private struct ReviewCountBadge: View {
    let value: String
    let accent: Color

    var body: some View {
        Text(value)
            .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
            .foregroundStyle(AppTheme.reviewTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent.opacity(0.16))
            .clipShape(Capsule())
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
