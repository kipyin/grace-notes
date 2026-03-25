import SwiftUI

private struct ReviewInsightPanelBodies {
    let observation: String
    let thread: String
    let action: String
}

// swiftlint:disable type_body_length
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
        return VStack(alignment: .leading, spacing: 0) {
            sourceBadgeRow(for: insights)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 10) {
                observationPanel(for: insights, body: bodies.observation)
                thinkingPanel(body: bodies.thread)
                actionPanel(body: bodies.action)
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

    private func observationPanel(for insights: ReviewInsights, body: String) -> some View {
        ReviewInsightInsetPanel(
            title: String(localized: "This week"),
            panelChrome: .lead,
            titleTrailingText: weekRangeText(insights)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                panelParagraph(body, lineSpacing: 4)

                let recurringGroups = recurringThemeGroups(for: insights)
                if !recurringGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(recurringGroups) { group in
                            ReviewRecurringThemeGroup(title: group.title, items: group.items)
                        }
                    }
                }
            }
        }
    }

    private func thinkingPanel(body: String) -> some View {
        ReviewInsightInsetPanel(title: String(localized: "A thread"), panelChrome: .standard) {
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
                        .padding(10)
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
        if !insights.recurringGratitudes.isEmpty {
            groups.append(
                RecurringThemeGroup(
                    title: String(localized: "Recurring Gratitudes"),
                    items: insights.recurringGratitudes
                )
            )
        }
        if !insights.recurringNeeds.isEmpty {
            groups.append(
                RecurringThemeGroup(
                    title: String(localized: "Recurring Needs"),
                    items: insights.recurringNeeds
                )
            )
        }
        if !insights.recurringPeople.isEmpty {
            groups.append(
                RecurringThemeGroup(
                    title: String(localized: "People in Mind"),
                    items: insights.recurringPeople
                )
            )
        }
        return groups
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
            sourceSkeletonRow
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 10) {
                skeletonInsetPanel(
                    title: String(localized: "This week"),
                    panelChrome: .lead,
                    lineSpecs: [(1.0, 12), (1.0, 12), (0.72, 12)]
                )
                skeletonInsetPanel(
                    title: String(localized: "A thread"),
                    panelChrome: .standard,
                    lineSpecs: [(1.0, 11), (0.84, 11)]
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.warmPaperMeta.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text(
                        String(
                            format: String(localized: "%1$@ (%2$lld)"),
                            item.label,
                            item.count
                        )
                    )
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextMuted)
                    .lineSpacing(2)
                }
                .padding(.leading, 4)
            }
        }
    }
}
