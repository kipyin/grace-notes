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
        .padding(.horizontal, 16)
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
                if insights.presentationMode == .insight {
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
            title: String(localized: "Past seven days rhythm"),
            panelChrome: .standard,
            titleTrailingText: weekRangeText(insights)
        ) {
            activityStrip(for: insights.weekStats)
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

    private func weekRangeText(_ insights: ReviewInsights) -> String {
        let calendar = Calendar.current
        let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: insights.weekEnd) ?? insights.weekEnd
        let startText = insights.weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = inclusiveEnd.formatted(.dateTime.month(.abbreviated).day())
        return String(
            format: String(localized: "%1$@ to %2$@"),
            startText,
            endText
        )
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
        let threadKey = normalizedInsightText(thread)
        let actionKey = normalizedInsightText(action)
        let actionDuplicatesPanel = actionKey == observationKey || actionKey == threadKey
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

    private func activityStrip(for stats: ReviewWeekStats) -> some View {
        HStack(spacing: 8) {
            ForEach(stats.activity, id: \.date) { day in
                VStack(spacing: 6) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                    Image(systemName: activityIconName(for: day))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(activityIconTint(for: day))
                        .frame(width: 16, height: 16)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(activityAccessibilityLabel(for: day))
            }
        }
    }

    private func localizedCompletionStageName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            String(localized: "Soil")
        case .seed:
            String(localized: "Seed")
        case .ripening:
            String(localized: "Ripening")
        case .harvest:
            String(localized: "Harvest")
        case .abundance:
            String(localized: "Abundance")
        }
    }

    private func activityIconName(for day: ReviewDayActivity) -> String {
        guard let level = day.strongestCompletionLevel else {
            return "circle"
        }
        return level.completionStatusSystemImage(isEmphasized: level == .harvest || level == .abundance)
    }

    private func activityIconTint(for day: ReviewDayActivity) -> Color {
        guard let level = day.strongestCompletionLevel else {
            return AppTheme.reviewTextMuted.opacity(0.35)
        }
        switch level {
        case .soil:
            return AppTheme.reviewTextMuted
        case .seed:
            return AppTheme.reviewQuickStartText
        case .ripening:
            return AppTheme.reviewStandardText
        case .harvest:
            return AppTheme.reviewAccent
        case .abundance:
            return AppTheme.reviewCompleteText
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
        if day.hasMeaningfulContent {
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
                    title: String(localized: "Past seven days rhythm"),
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
