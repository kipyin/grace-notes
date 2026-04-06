import SwiftUI

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
            return String(localized: "common.new")
        case .rising:
            return String(localized: "common.direction.up")
        case .down:
            return String(localized: "common.direction.down")
        case .stable:
            return String(localized: "review.labels.stable")
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
                        format: String(localized: "review.history.weekComparisonArrow"),
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
        trendWords = String(localized: "common.new")
    case .rising:
        trendWords = String(localized: "common.direction.up")
    case .down:
        trendWords = String(localized: "common.direction.down")
    case .stable:
        trendWords = String(localized: "review.labels.stable")
    }
    if trend == .new {
        return String(
            format: String(localized: "journal.share.lineCountsThree"),
            label,
            trendWords,
            Int64(currentWeekCount)
        )
    }
    return String(
        format: String(localized: "journal.share.lineCountsFour"),
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
    let referenceDate: Date
    let calendar: Calendar
}

struct TrendingBrowsePayload: Identifiable {
    let id = UUID()
    let buckets: ReviewTrendingBuckets
}

struct MostRecurringBrowseSheetContainer: View {
    let themes: [ReviewMostRecurringTheme]
    let referenceDate: Date
    let calendar: Calendar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MostRecurringThemesBrowseView(themes: themes, referenceDate: referenceDate, calendar: calendar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        PastToolbarDoneButton(
                            action: { dismiss() },
                            accessibilityIdentifier: "MostRecurringBrowseSheetDone"
                        )
                    }
                }
        }
    }
}

struct TrendingBrowseSheetContainer: View {
    let buckets: ReviewTrendingBuckets

    var body: some View {
        NavigationStack {
            TrendingThemesBrowseView(buckets: buckets)
        }
    }
}

struct MostRecurringThemesBrowseView: View {
    let themes: [ReviewMostRecurringTheme]
    let referenceDate: Date
    let calendar: Calendar
    @AppStorage(PastStatisticsIntervalPreference.appStorageKey)
    private var pastStatisticsIntervalEncoded = ""

    var body: some View {
        List {
            if !gratitudeRows.isEmpty {
                recurringSection(
                    section: .gratitudes,
                    title: String(localized: "journal.section.gratitudesTitle"),
                    rows: gratitudeRows
                )
            }
            if !needsRows.isEmpty {
                recurringSection(
                    section: .needs,
                    title: String(localized: "journal.section.needsTitle"),
                    rows: needsRows
                )
            }
            if !peopleRows.isEmpty {
                recurringSection(
                    section: .people,
                    title: String(localized: "journal.section.peopleTitle"),
                    rows: peopleRows
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .navigationTitle(String(localized: "review.labels.mostRecurring"))
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
                .buttonStyle(PastTappablePressStyle())
                .accessibilityIdentifier("MostRecurringThemeBrowseRow.\(row.accessibilityId)")
            }
        } header: {
            Text(title)
                .textCase(nil)
                .accessibilityIdentifier("MostRecurringBrowseSection.\(section.rawValue)")
        }
    }

    private var pastStatisticsSelection: PastStatisticsIntervalSelection {
        PastStatisticsIntervalPreference.selection(fromAppStorage: pastStatisticsIntervalEncoded).validated
    }

    private var viewingDateRange: Range<Date> {
        let selection = pastStatisticsSelection
        if selection.mode == .all {
            let refStart = calendar.startOfDay(for: referenceDate)
            guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: refStart) else {
                return refStart..<refStart
            }
            let evidenceDays = themes.flatMap(\.evidence).map { calendar.startOfDay(for: $0.entryDate) }
            let low = evidenceDays.min() ?? refStart
            return low..<endExclusive
        }
        return selection.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: []
        )
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
            sectionTitle: String(localized: "review.labels.mostRecurring"),
            subtitle: pastStatisticsSelection.mostRecurringDrilldownSubtitle(mentionCount: row.mentionCount),
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

struct TrendingThemesBrowseView: View {
    let buckets: ReviewTrendingBuckets
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !buckets.newThemes.isEmpty {
                trendingSection(title: String(localized: "common.new"), themes: buckets.newThemes)
            }
            if !buckets.upThemes.isEmpty {
                trendingSection(title: String(localized: "common.direction.up"), themes: buckets.upThemes)
            }
            if !buckets.downThemes.isEmpty {
                trendingSection(title: String(localized: "common.direction.down"), themes: buckets.downThemes)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .navigationTitle(String(localized: "review.labels.trending"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PastToolbarDoneButton(
                    action: { dismiss() },
                    accessibilityIdentifier: "TrendingBrowseSheetDone"
                )
            }
        }
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
                .buttonStyle(PastTappablePressStyle())
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
            sectionTitle: String(localized: "review.labels.trending"),
            subtitle: String(
                format: String(localized: "review.insights.weekComparisonCurrentPrevious"),
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
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue

    private var groupingCalendar: Calendar {
        ReviewWeekBoundaryPreference.resolve(from: reviewWeekBoundaryRawValue).configuredCalendar()
    }

    private var evidenceGroupedByDay: [(day: Date, rows: [ReviewThemeSurfaceEvidence])] {
        let cal = groupingCalendar
        let grouped = Dictionary(grouping: payload.evidence) { cal.startOfDay(for: $0.entryDate) }
        return grouped.keys.sorted(by: >).map { day in
            let rows = (grouped[day] ?? []).sorted { lhs, rhs in
                if lhs.source != rhs.source {
                    return lhs.source.rawValue < rhs.source.rawValue
                }
                return lhs.content.localizedCaseInsensitiveCompare(rhs.content) == .orderedAscending
            }
            return (day, rows)
        }
    }

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
                    Text(String(localized: "review.labels.summary"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                }

                if !payload.evidence.isEmpty {
                    Section {
                        ForEach(evidenceGroupedByDay, id: \.day) { group in
                            Section {
                                ForEach(group.rows) { evidence in
                                    NavigationLink {
                                        JournalScreen(entryDate: evidence.entryDate)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(evidence.source.localizedJournalSurfaceTitle)
                                                .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                            Text(evidence.content)
                                                .font(AppTheme.warmPaperBody)
                                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(PastTappablePressStyle())
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(
                                        themeDrilldownRowAccessibilityLabel(day: group.day, evidence: evidence)
                                    )
                                    .accessibilityHint(String(localized: "review.themeDrilldown.openEntry.a11yHint"))
                                }
                            } header: {
                                Text(group.day.formatted(date: .abbreviated, time: .omitted))
                                    .font(AppTheme.warmPaperMeta)
                                    .foregroundStyle(AppTheme.reviewTextMuted)
                                    .textCase(nil)
                            }
                        }
                    } header: {
                        Text(String(localized: "review.labels.matchingSurfaces"))
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.reviewBackground)
            .navigationTitle(String(localized: "review.labels.themeDetails"))
            .toolbar {
                if includeDoneButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        PastToolbarDoneButton(action: { dismiss() })
                    }
                }
            }
        }
    }

    private func themeDrilldownRowAccessibilityLabel(
        day: Date,
        evidence: ReviewThemeSurfaceEvidence
    ) -> String {
        let dayText = day.formatted(date: .abbreviated, time: .omitted)
        return [
            dayText,
            evidence.source.localizedJournalSurfaceTitle,
            evidence.content
        ].joined(separator: ", ")
    }

}
