import SwiftUI

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

    @State private var showCloudSkipExplanation = false
    @State private var cloudSkipExplanationMessage = ""

    let insights: ReviewInsights?
    let aiFeaturesEnabled: Bool
    let isLoading: Bool
    let weekJournalEntryCount: Int
    let onContinueToToday: () -> Void

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
        .alert(
            String(localized: "On your device this week"),
            isPresented: $showCloudSkipExplanation
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(cloudSkipExplanationMessage)
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
        let recurringGroups = recurringThemeGroups(for: insights)
        return VStack(alignment: .leading, spacing: 0) {
            if AppFeatureFlags.cloudAIUserFacingEnabled {
                sourceBadgeRow(for: insights)
                    .padding(.bottom, 8)
            }
            VStack(alignment: .leading, spacing: 10) {
                weekRhythmPanel(for: insights)
                if !recurringGroups.isEmpty {
                    recurringThemesPanel(groups: recurringGroups)
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

    private func recurringThemesPanel(groups: [RecurringThemeGroup]) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "Most recurring"),
            panelChrome: .standard
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(groups) { group in
                    ReviewRecurringThemeGroup(
                        title: group.title,
                        items: group.items,
                        accent: group.accent
                    )
                }
            }
        }
    }

    private func panelParagraph(_ text: String, lineSpacing: CGFloat) -> some View {
        Text(trimmed(text))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.reviewTextPrimary)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sourceBadgeRow(for insights: ReviewInsights) -> some View {
        let badgeLabel = sourceBadgeLabel(for: insights.source)
        let showCloudSkipInfo = aiFeaturesEnabled
            && insights.source == .deterministic
            && insights.cloudSkippedReason != nil

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(badgeLabel)
                .font(AppTheme.warmPaperMeta.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.reviewAccent.opacity(0.2))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
                }

            if showCloudSkipInfo {
                Button {
                    if let reason = insights.cloudSkippedReason {
                        cloudSkipExplanationMessage = reason.localizedExplanation
                        showCloudSkipExplanation = true
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(AppTheme.warmPaperMeta.weight(.semibold))
                        .foregroundStyle(AppTheme.reviewAccent)
                        .imageScale(.small)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Why on-device insights this week"))
                .accessibilityHint(String(localized: "Shows why Cloud AI wasn't used for this weekly digest."))
                .accessibilityIdentifier("ReviewInsightCloudSkipInfoButton")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func sourceBadgeLabel(for source: ReviewInsightSource) -> String {
        switch source {
        case .deterministic:
            String(localized: "Source: On your device")
        case .cloudAI:
            String(localized: "Source: Cloud AI")
        }
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

    private func recurringThemeGroups(for insights: ReviewInsights) -> [RecurringThemeGroup] {
        var groups: [RecurringThemeGroup] = []
        let recurringGratitudes = insights.recurringGratitudes.filter { $0.count > 1 }
        let recurringNeeds = insights.recurringNeeds.filter { $0.count > 1 }
        let recurringPeople = insights.recurringPeople.filter { $0.count > 1 }
        if !recurringGratitudes.isEmpty {
            groups.append(
                RecurringThemeGroup(
                    title: localizedSectionName(for: .gratitudes),
                    items: recurringGratitudes,
                    accent: AppTheme.reviewAccent
                )
            )
        }
        if !recurringNeeds.isEmpty {
            groups.append(
                RecurringThemeGroup(
                    title: localizedSectionName(for: .needs),
                    items: recurringNeeds,
                    accent: AppTheme.reviewStandardBorder
                )
            )
        }
        if !recurringPeople.isEmpty {
            groups.append(
                RecurringThemeGroup(
                    title: String(localized: "People in Mind"),
                    items: recurringPeople,
                    accent: AppTheme.reviewCompleteBorder
                )
            )
        }
        return groups
    }

    private func localizedSectionName(for section: ReviewStatsSectionKind) -> String {
        switch section {
        case .gratitudes:
            String(localized: "Gratitudes")
        case .needs:
            String(localized: "Needs")
        case .people:
            String(localized: "People in Mind")
        }
    }

    private func rhythmHistoryCurve(for insights: ReviewInsights) -> some View {
        let stats = insights.weekStats
        let days = stats.rhythmHistory ?? stats.activity
        let currentWeek = insights.weekStart..<insights.weekEnd
        let metrics = RhythmCurveScaledMetrics(dynamicTypeSize: dynamicTypeSize)

        return ScrollViewReader { proxy in
            rhythmHistoryScrollSection(
                proxy: proxy,
                days: days,
                currentWeek: currentWeek,
                metrics: metrics
            )
        }
    }

    @ViewBuilder
    private func rhythmHistoryScrollSection(
        proxy: ScrollViewProxy,
        days: [ReviewDayActivity],
        currentWeek: Range<Date>,
        metrics: RhythmCurveScaledMetrics
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
        }
        .frame(minHeight: metrics.horizontalScrollMinHeight)
        .overlay {
            rhythmHorizontalFeatherOverlay(daysCount: days.count, metrics: metrics)
        }
        .onAppear {
            guard let last = days.last else { return }
            DispatchQueue.main.async {
                proxy.scrollTo(last.date, anchor: .trailing)
            }
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
        LazyHStack(alignment: .center, spacing: metrics.columnGap) {
            Color.clear
                .frame(width: metrics.chartHorizontalPadding)
                .accessibilityHidden(true)
            ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                let cornerRadii = rhythmColumnCornerRadii(
                    index: index,
                    count: days.count,
                    radius: metrics.columnCornerRadius
                )
                NavigationLink {
                    JournalScreen(entryDate: day.date)
                } label: {
                    rhythmColumnChart(day: day, metrics: metrics)
                        .frame(width: metrics.columnWidth)
                        .background {
                            UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
                                .fill(AppTheme.reviewRhythmColumnFill)
                        }
                        .overlay {
                            UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
                                .stroke(AppTheme.reviewRhythmColumnStroke.opacity(0.58), lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(activityAccessibilityLabel(for: day))
                .accessibilityHint(String(localized: "Opens that day's entry."))
                .accessibilityIdentifier(accessibilityRhythmColumnId(for: day))
                .id(day.date)
            }
            Color.clear
                .frame(width: metrics.chartHorizontalPadding)
                .accessibilityHidden(true)
        }
        .frame(minHeight: metrics.chartRowMinHeight)
    }

    /// Weekday / M·d labels aligned under columns (below column fills).
    @ViewBuilder
    private func rhythmLabelRow(
        days: [ReviewDayActivity],
        currentWeek: Range<Date>,
        metrics: RhythmCurveScaledMetrics
    ) -> some View {
        LazyHStack(alignment: .top, spacing: metrics.columnGap) {
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
        "ReviewRhythmDay.\(day.date.timeIntervalSince1970)"
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

    private struct RecurringThemeGroup: Identifiable {
        let title: String
        let items: [ReviewInsightTheme]
        let accent: Color

        var id: String { title }
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

/// Background and stroke only; panel titles share one typographic style.
private enum ReviewInsightPanelChrome {
    case lead
    case standard
}

private struct InsightsLoadingSkeleton: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if AppFeatureFlags.cloudAIUserFacingEnabled {
                sourceSkeletonRow
                    .padding(.bottom, 8)
            }
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

    private var sourceSkeletonRow: some View {
        InsightsPlaceholderBar(widthFraction: 1, height: 13)
            .frame(width: 200, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ReviewInsightInsetPanel<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let panelChrome: ReviewInsightPanelChrome
    let titleTrailingText: String?
    let content: Content

    init(
        title: String,
        panelChrome: ReviewInsightPanelChrome = .standard,
        titleTrailingText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.panelChrome = panelChrome
        self.titleTrailingText = titleTrailingText
        self.content = content()
    }

    private var strokeOpacity: CGFloat {
        switch panelChrome {
        case .lead:
            return 0.55
        case .standard:
            return 0.4
        }
    }

    private var titleText: some View {
        Text(title)
            .font(AppTheme.warmPaperBody.weight(.semibold))
            .foregroundStyle(AppTheme.reviewTextPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var titleRow: some View {
        if let trailing = titleTrailingText, !trailing.isEmpty {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    titleText
                    Text(trailing)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        titleText
                        Spacer(minLength: 8)
                        Text(trailing)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.85)
                            .lineLimit(2)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        titleText
                        Text(trailing)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                    }
                }
            }
        } else {
            titleText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `reviewPaper` on `reviewBackground` (list row); avoid low-opacity `reviewBackground` here — it vanishes.
        .background(AppTheme.reviewPaper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.border.opacity(strokeOpacity), lineWidth: 1)
        )
    }
}

private struct ReviewRecurringThemeGroup: View {
    let title: String
    let items: [ReviewInsightTheme]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(AppTheme.warmPaperMeta.weight(.semibold))
                    .foregroundStyle(AppTheme.reviewTextPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.label)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .lineSpacing(2)
                        Spacer(minLength: 8)
                        ReviewCountBadge(value: item.count.formatted(), accent: accent)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(
                            format: String(localized: "%1$@ (%2$lld)"),
                            item.label,
                            Int64(item.count)
                        )
                    )
                }
            }
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

// swiftlint:enable file_length
