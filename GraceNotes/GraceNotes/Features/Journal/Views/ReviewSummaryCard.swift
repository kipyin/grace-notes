import SwiftUI

private struct ReviewInsightPanelBodies {
    let observation: String
    let thread: String
    let action: String
}

// swiftlint:disable type_body_length
struct ReviewSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let insights: ReviewInsights?
    let isLoading: Bool

    private let observationCharacterCap = 360
    private let thinkingCharacterCap = 480
    private let actionCharacterCap = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading, insights == nil {
                ProgressView()
                    .tint(AppTheme.reviewAccent)
            } else if let insights {
                insightsContent(for: insights)
            } else {
                Text(String(localized: "Start writing this week to unlock review insights."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.reviewTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(AppTheme.reviewPaper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.4), lineWidth: 1)
        )
    }

    private func insightsContent(for insights: ReviewInsights) -> some View {
        let bodies = dedupedPanelBodies(for: insights)
        return VStack(alignment: .leading, spacing: 0) {
            sourceRow(for: insights.source)
                .padding(.bottom, 8)

            Text(weekRangeText(insights))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 10) {
                observationPanel(for: insights, body: bodies.observation)
                thinkingPanel(body: bodies.thread)
                actionPanel(body: bodies.action)
            }
        }
    }

    private func observationPanel(for insights: ReviewInsights, body: String) -> some View {
        ReviewInsightInsetPanel(title: String(localized: "This week")) {
            VStack(alignment: .leading, spacing: 12) {
                panelParagraph(
                    body,
                    maxCharacters: observationCharacterCap,
                    lineLimit: 4,
                    lineSpacing: 4
                )

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
        ReviewInsightInsetPanel(title: String(localized: "A thread")) {
            panelParagraph(
                body,
                maxCharacters: thinkingCharacterCap,
                lineLimit: 5,
                lineSpacing: 4
            )
        }
    }

    private func actionPanel(body: String) -> some View {
        ReviewInsightInsetPanel(title: String(localized: "A next step")) {
            panelParagraph(
                body,
                maxCharacters: actionCharacterCap,
                lineLimit: 2,
                lineSpacing: 4
            )
        }
    }

    private func panelParagraph(
        _ text: String,
        maxCharacters: Int,
        lineLimit: Int,
        lineSpacing: CGFloat
    ) -> some View {
        Text(truncated(text, maxCharacters: maxCharacters))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.reviewTextPrimary)
            .lineSpacing(lineSpacing)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
    }

    @ViewBuilder
    private func sourceRow(for source: ReviewInsightSource) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                sourceLabelAndChip(for: source)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    sourceLabelAndChip(for: source)
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    sourceLabelAndChip(for: source)
                }
            }
        }
    }

    private func sourceLabelAndChip(for source: ReviewInsightSource) -> some View {
        HStack(spacing: 8) {
            Text(String(localized: "Source"))
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
            Text(insightSourceText(source))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.reviewBackground)
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private func insightSourceText(_ source: ReviewInsightSource) -> String {
        switch source {
        case .cloudAI:
            return String(localized: "AI")
        case .deterministic:
            return String(localized: "On-device")
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

    private func truncated(_ text: String, maxCharacters: Int) -> String {
        let cleaned = trimmed(text)
        guard cleaned.count > maxCharacters else {
            return cleaned
        }
        let cutIndex = cleaned.index(cleaned.startIndex, offsetBy: maxCharacters)
        return String(cleaned[..<cutIndex]) + "..."
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

private struct ReviewInsightInsetPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.reviewBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
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
