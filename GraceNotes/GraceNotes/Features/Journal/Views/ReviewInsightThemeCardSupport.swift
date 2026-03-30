import SwiftUI

// MARK: - Loading primitives

/// Soft, static bars — motion (if any) comes from ``InsightsCalmLoadingBreath`` on the whole skeleton.
struct InsightsPlaceholderBar: View {
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
struct InsightsCalmLoadingBreath: ViewModifier {
    let active: Bool
    private var period: Double { 5.5 }
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

func reviewInsightSanitizedThemeId(_ value: String) -> String {
    let cleaned = value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    if cleaned.isEmpty {
        return "theme"
    }
    return cleaned
}

// MARK: - Badges

struct ReviewTrendBadge: View {
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

/// Compact counts for calendar-week trending rows. New themes show the current week count only;
/// other trends use `previous → current`.
struct ReviewTrendCountCapsule: View {
    let trend: ReviewThemeTrend
    let previous: Int
    let current: Int
    let accent: Color

    var body: some View {
        Group {
            if trend == .new {
                ReviewCountBadge(
                    value: current.formatted(),
                    accent: accent
                )
            } else {
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
    }
}

/// VoiceOver label for a trending theme row: omits prior-week count when the theme is new.
func reviewTrendingThemeRowAccessibilityLabel(
    label: String,
    trend: ReviewThemeTrend,
    previousWeekCount: Int,
    currentWeekCount: Int
) -> String {
    let trendWords: String
    switch trend {
    case .new:
        trendWords = String(localized: "New")
    case .rising:
        trendWords = String(localized: "Up")
    case .down:
        trendWords = String(localized: "Down")
    case .stable:
        trendWords = String(localized: "Stable")
    }
    if trend == .new {
        return String(
            format: String(localized: "%1$@, %2$@, %3$lld"),
            label,
            trendWords,
            Int64(currentWeekCount)
        )
    }
    return String(
        format: String(localized: "%1$@, %2$@, %3$lld, %4$lld"),
        label,
        trendWords,
        Int64(previousWeekCount),
        Int64(currentWeekCount)
    )
}

struct ReviewCountBadge: View {
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

// MARK: - Drilldown & browse

struct ReviewThemeDrilldownPayload: Identifiable {
    let label: String
    let sectionTitle: String
    let subtitle: String
    let trend: ReviewThemeTrend?
    let evidence: [ReviewThemeSurfaceEvidence]

    var id: String {
        "\(sectionTitle)|\(label)"
    }
}

struct MostRecurringBrowsePayload: Identifiable {
    let id = UUID()
    let themes: [ReviewMostRecurringTheme]
    let reviewWeekEnd: Date
    let calendar: Calendar
}

struct TrendingBrowsePayload: Identifiable {
    let id = UUID()
    let buckets: ReviewTrendingBuckets
}

struct MostRecurringBrowseSheetContainer: View {
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

struct TrendingBrowseSheetContainer: View {
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

struct MostRecurringThemesBrowseView: View {
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
                .pickerStyle(.segmented)
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

struct MostRecurringBrowseRowModel: Identifiable {
    let label: String
    let themeId: String
    let section: ReviewThemeSourceCategory
    let mentionCount: Int
    let evidence: [ReviewThemeSurfaceEvidence]

    var id: String { "\(themeId)|\(section.rawValue)" }

    var accessibilityId: String {
        "\(reviewInsightSanitizedThemeId(themeId)).\(section.rawValue)"
    }
}

enum MostRecurringBrowseWindow: Int, CaseIterable, Identifiable {
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

struct TrendingThemesBrowseView: View {
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
                            trend: theme.trend,
                            previous: theme.previousWeekCount,
                            current: theme.currentWeekCount,
                            accent: movementAccent(theme.trend)
                        )
                    }
                }
                .accessibilityLabel(
                    reviewTrendingThemeRowAccessibilityLabel(
                        label: theme.label,
                        trend: theme.trend,
                        previousWeekCount: theme.previousWeekCount,
                        currentWeekCount: theme.currentWeekCount
                    )
                )
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
                format: String(localized: "Current week %1$lld, previous week %2$lld."),
                Int64(theme.currentWeekCount),
                Int64(theme.previousWeekCount)
            ),
            trend: theme.trend,
            evidence: theme.evidence
        )
    }
}

struct ThemeDrilldownSheet: View {
    let payload: ReviewThemeDrilldownPayload

    var body: some View {
        ThemeDrilldownView(payload: payload, includeDoneButton: true)
    }
}

struct ThemeDrilldownView: View {
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
