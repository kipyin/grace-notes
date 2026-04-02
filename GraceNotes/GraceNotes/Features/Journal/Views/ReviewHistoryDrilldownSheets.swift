import SwiftUI

enum ReviewHistoryDrilldownPayload: Identifiable, Equatable {
    case growthStage(JournalCompletionLevel)
    case section(ReviewStatsSectionKind)

    var id: String {
        switch self {
        case .growthStage(let level):
            "growth-\(level.rawValue)"
        case .section(let kind):
            "section-\(kind.rawValue)"
        }
    }
}

struct ReviewHistoryDrilldownSheetContainer: View {
    let payload: ReviewHistoryDrilldownPayload
    let entries: [JournalEntry]
    let calendar: Calendar
    let referenceDate: Date
    let pastStatisticsInterval: PastStatisticsIntervalSelection

    var body: some View {
        switch payload {
        case .growthStage(let level):
            GrowthStageDrilldownSheet(
                level: level,
                entries: entries,
                calendar: calendar,
                referenceDate: referenceDate,
                pastStatisticsInterval: pastStatisticsInterval
            )
        case .section(let kind):
            SectionEntriesDrilldownSheet(
                section: kind,
                entries: entries,
                calendar: calendar,
                referenceDate: referenceDate,
                pastStatisticsInterval: pastStatisticsInterval
            )
        }
    }
}

// MARK: - Growth stage

private struct GrowthStageDrilldownSheet: View {
    @Environment(\.dismiss) private var dismiss

    let level: JournalCompletionLevel
    private let matchingDays: [Date]

    init(
        level: JournalCompletionLevel,
        entries: [JournalEntry],
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) {
        self.level = level
        let historyEntries = ReviewHistoryWindowing.entriesInValidatedHistoryWindow(
            allEntries: entries,
            referenceDate: referenceDate,
            calendar: calendar,
            pastStatisticsInterval: pastStatisticsInterval
        )
        let strongestByDay = ReviewHistoryWindowing.strongestCompletionByDay(
            from: historyEntries,
            calendar: calendar
        )
        matchingDays = ReviewHistoryWindowing.calendarDaysMatchingStrongestCompletionLevel(
            level,
            strongestByDay: strongestByDay
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(growthStageCriterion(for: level))
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                } header: {
                    Text(String(localized: "Summary"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                }

                Section {
                    ForEach(matchingDays, id: \.self) { day in
                        NavigationLink {
                            JournalScreen(entryDate: day)
                        } label: {
                            Text(day.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityHint(String(localized: "ThemeDrilldown.openEntry.a11yHint"))
                    }
                } header: {
                    Text(String(localized: "Review history growth drilldown dates section"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.reviewBackground)
            .navigationTitle(growthStageDisplayTitle(for: level))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func growthStageDisplayTitle(for level: JournalCompletionLevel) -> String {
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

    private func growthStageCriterion(for level: JournalCompletionLevel) -> String {
        switch level {
        case .empty:
            String(localized: "PostSeedJourney.path.criterion.empty")
        case .started:
            String(localized: "PostSeedJourney.path.criterion.started")
        case .growing:
            String(localized: "PostSeedJourney.path.criterion.growing")
        case .balanced:
            String(localized: "PostSeedJourney.path.criterion.balanced")
        case .full:
            String(localized: "PostSeedJourney.path.criterion.full")
        }
    }
}

// MARK: - Section entries

private struct SectionEntriesDrilldownSheet: View {
    @Environment(\.dismiss) private var dismiss

    let section: ReviewStatsSectionKind
    private let contributingEntries: [JournalEntry]

    init(
        section: ReviewStatsSectionKind,
        entries: [JournalEntry],
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) {
        self.section = section
        let historyEntries = ReviewHistoryWindowing.entriesInValidatedHistoryWindow(
            allEntries: entries,
            referenceDate: referenceDate,
            calendar: calendar,
            pastStatisticsInterval: pastStatisticsInterval
        )
        contributingEntries = ReviewHistoryWindowing.entriesContributingToSection(
            section,
            in: historyEntries
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if contributingEntries.isEmpty {
                    ContentUnavailableView {
                        Label(
                            String(localized: "Review section drilldown empty title"),
                            systemImage: "doc.text.magnifyingglass"
                        )
                    } description: {
                        Text(
                            String(
                                format: String(localized: "Review section drilldown empty format"),
                                localizedSectionTitle(for: section)
                            )
                        )
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(contributingEntries, id: \.id) { entry in
                        NavigationLink {
                            JournalScreen(entryDate: entry.entryDate)
                        } label: {
                            Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            entry.entryDate.formatted(date: .complete, time: .omitted)
                        )
                        .accessibilityHint(String(localized: "ThemeDrilldown.openEntry.a11yHint"))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.reviewBackground)
            .navigationTitle(localizedSectionTitle(for: section))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func localizedSectionTitle(for kind: ReviewStatsSectionKind) -> String {
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
