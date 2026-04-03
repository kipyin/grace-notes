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
    let entries: [Journal]
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var journalNavigationDay: ReviewHistoryDrilldownJournalNavigationDay?

    let level: JournalCompletionLevel
    private let matchingDayStarts: Set<Date>
    private let historyJournalDays: Set<Date>
    private let historyDayRange: Range<Date>
    private let displayRange: Range<Date>
    private let drilldownCalendar: Calendar

    init(
        level: JournalCompletionLevel,
        entries: [Journal],
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) {
        self.level = level
        drilldownCalendar = calendar
        historyDayRange = pastStatisticsInterval.validated.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: entries
        )
        displayRange = ReviewHistoryDrilldownCalendarLayout.drilldownGridDisplayRange(
            entries: entries,
            historyDayRange: historyDayRange,
            calendar: calendar
        )
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
        let matchedDays = ReviewHistoryWindowing.calendarDaysMatchingStrongestCompletionLevel(
            level,
            strongestByDay: strongestByDay
        )
        matchingDayStarts = Set(matchedDays.map { calendar.startOfDay(for: $0) })
        historyJournalDays = ReviewHistoryWindowing.journalEntryDayStarts(
            fromHistoryEntries: historyEntries,
            calendar: calendar
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
                    if matchingDayStarts.isEmpty {
                        ContentUnavailableView {
                            Label(
                                String(localized: "Review history growth drilldown calendar empty title"),
                                systemImage: "calendar"
                            )
                        } description: {
                            Text(String(localized: "Review history growth drilldown calendar empty description"))
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.reviewTextMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        ReviewHistoryDrilldownCalendarGrid(
                            matchingDayStarts: matchingDayStarts,
                            journalDaysInHistoryWindow: historyJournalDays,
                            historyDayRange: historyDayRange,
                            displayRange: displayRange,
                            calendar: drilldownCalendar,
                            growthStageForMatchedDays: level,
                            sectionStripChipCountsByDay: nil,
                            onMatchingDaySelected: { day in
                                journalNavigationDay = ReviewHistoryDrilldownJournalNavigationDay(
                                    dayStart: day,
                                    calendar: drilldownCalendar
                                )
                            }
                        )
                        .padding(.vertical, 4)
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        ReviewGrowthStageSkylineGlyph(level: level, dynamicTypeSize: dynamicTypeSize)
                        Text(growthStageDisplayTitle(for: level))
                            .font(AppTheme.warmPaperBody.weight(.semibold))
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $journalNavigationDay) { item in
                JournalScreen(entryDate: item.date)
            }
        }
    }

    private func growthStageDisplayTitle(for level: JournalCompletionLevel) -> String {
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

    private func growthStageCriterion(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            String(localized: "AppTour.path.criterion.empty")
        case .sprout:
            String(localized: "AppTour.path.criterion.started")
        case .twig:
            String(localized: "AppTour.path.criterion.growing")
        case .leaf:
            String(localized: "AppTour.path.criterion.balanced")
        case .bloom:
            String(localized: "AppTour.path.criterion.full")
        }
    }
}

// MARK: - Section entries

private struct SectionEntriesDrilldownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var journalNavigationDay: ReviewHistoryDrilldownJournalNavigationDay?

    let section: ReviewStatsSectionKind
    private let contributingEntries: [Journal]
    private let sectionMatchingDayStarts: Set<Date>
    private let historyJournalDays: Set<Date>
    private let sectionStripChipCountsByDay: [Date: Int]
    private let historyDayRange: Range<Date>
    private let displayRange: Range<Date>
    private let drilldownCalendar: Calendar

    init(
        section: ReviewStatsSectionKind,
        entries: [Journal],
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) {
        self.section = section
        drilldownCalendar = calendar
        historyDayRange = pastStatisticsInterval.validated.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: entries
        )
        displayRange = ReviewHistoryDrilldownCalendarLayout.drilldownGridDisplayRange(
            entries: entries,
            historyDayRange: historyDayRange,
            calendar: calendar
        )
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
        sectionMatchingDayStarts = Set(
            contributingEntries.map { calendar.startOfDay(for: $0.entryDate) }
        )
        historyJournalDays = ReviewHistoryWindowing.journalEntryDayStarts(
            fromHistoryEntries: historyEntries,
            calendar: calendar
        )
        sectionStripChipCountsByDay = ReviewHistoryWindowing.sectionChipCountByMatchedDays(
            section: section,
            matchingDayStarts: sectionMatchingDayStarts,
            contributingEntriesNewestFirst: contributingEntries,
            calendar: calendar
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
                    List {
                        ReviewHistoryDrilldownCalendarGrid(
                            matchingDayStarts: sectionMatchingDayStarts,
                            journalDaysInHistoryWindow: historyJournalDays,
                            historyDayRange: historyDayRange,
                            displayRange: displayRange,
                            calendar: drilldownCalendar,
                            growthStageForMatchedDays: nil,
                            sectionStripChipCountsByDay: sectionStripChipCountsByDay,
                            onMatchingDaySelected: { day in
                                journalNavigationDay = ReviewHistoryDrilldownJournalNavigationDay(
                                    dayStart: day,
                                    calendar: drilldownCalendar
                                )
                            }
                        )
                        .padding(.vertical, 4)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.reviewBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(localizedSectionTitle(for: section))
                        .font(AppTheme.warmPaperBody.weight(.semibold))
                        .foregroundStyle(AppTheme.reviewTextPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $journalNavigationDay) { item in
                JournalScreen(entryDate: item.date)
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
