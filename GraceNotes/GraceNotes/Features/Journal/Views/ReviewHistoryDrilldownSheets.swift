import SwiftUI

private struct ReviewHistoryDrilldownAbovePeekHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MeasureHeightModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ReviewHistoryDrilldownAbovePeekHeightKey.self,
                    value: proxy.size.height
                )
            }
        )
    }
}

extension View {
    fileprivate func reviewHistoryDrilldownMeasureAbovePeekHeight() -> some View {
        modifier(MeasureHeightModifier())
    }
}

/// Layout values shared by ``ReviewHistoryDrilldownPeekContainer``'s height math and its ``VStack`` (keep in sync).
private enum ReviewHistoryDrilldownPeekContainerLayout {
    /// Must match ``VStack`` `spacing` between `above` and `grid` when there is real header content.
    static let aboveToGridSpacing: CGFloat = 12
    /// Single value passed to ``View/padding(_:_:)`` for vertical padding on the ``VStack``.
    static let verticalPadding: CGFloat = 8
    /// Top + bottom padding total (derived from ``verticalPadding``).
    static var verticalPaddingTotal: CGFloat { verticalPadding * 2 }
}

/// Single scroll owner for drill-down: only ``ReviewHistoryDrilldownCalendarGrid``'s `ScrollView` moves.
private struct ReviewHistoryDrilldownPeekContainer<Above: View, GridContent: View>: View {
    let above: Above
    @Binding var abovePeekHeight: CGFloat
    /// Spacing between measured `above` and the calendar; use `0` when `above` is a zero-height placeholder.
    let aboveAndGridSpacing: CGFloat
    /// Builds the feathered calendar; receives clamped peek height from ``GeometryReader``.
    let grid: (CGFloat) -> GridContent

    init(
        above: Above,
        abovePeekHeight: Binding<CGFloat>,
        aboveAndGridSpacing: CGFloat = ReviewHistoryDrilldownPeekContainerLayout.aboveToGridSpacing,
        grid: @escaping (CGFloat) -> GridContent
    ) {
        self.above = above
        _abovePeekHeight = abovePeekHeight
        self.aboveAndGridSpacing = aboveAndGridSpacing
        self.grid = grid
    }

    var body: some View {
        GeometryReader { proxy in
            let remaining = proxy.size.height
                - abovePeekHeight
                - ReviewHistoryDrilldownPeekContainerLayout.verticalPaddingTotal
                - aboveAndGridSpacing
            let peek = ReviewHistoryDrilldownPeekMetrics.clampedViewportHeight(remainingHeight: remaining)

            VStack(alignment: .leading, spacing: aboveAndGridSpacing) {
                above
                    .reviewHistoryDrilldownMeasureAbovePeekHeight()
                grid(peek)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, ReviewHistoryDrilldownPeekContainerLayout.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onPreferenceChange(ReviewHistoryDrilldownAbovePeekHeightKey.self) { abovePeekHeight = $0 }
        }
    }
}

enum ReviewHistoryDrilldownPayload: Identifiable, Equatable {
    case growthStage(JournalCompletionLevel)
    case section(ReviewStatsSectionKind)
    case journalingDays

    var id: String {
        switch self {
        case .growthStage(let level):
            "growth-\(level.rawValue)"
        case .section(let kind):
            "section-\(kind.rawValue)"
        case .journalingDays:
            "journaling-days"
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
        case .journalingDays:
            JournalingDaysDrilldownSheet(
                entries: entries,
                calendar: calendar,
                referenceDate: referenceDate,
                pastStatisticsInterval: pastStatisticsInterval
            )
        }
    }
}

// MARK: - Journaling days (rhythm chrome)

private struct JournalingDaysDrilldownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var journalNavigationDay: ReviewHistoryDrilldownJournalNavigationDay?
    @State private var abovePeekHeight: CGFloat = 0

    private let historyJournalDays: Set<Date>
    private let historyDayRange: Range<Date>
    private let displayRange: Range<Date>
    private let drilldownCalendar: Calendar

    init(
        entries: [Journal],
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) {
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
        historyJournalDays = ReviewHistoryWindowing.journalEntryDayStarts(
            fromHistoryEntries: historyEntries,
            calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if historyJournalDays.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            ContentUnavailableView {
                                Label(
                                    String(localized: "Review history journaling days drilldown empty title"),
                                    systemImage: "calendar"
                                )
                            } description: {
                                Text(String(localized: "Review history journaling days drilldown empty description"))
                                    .font(AppTheme.warmPaperBody)
                                    .foregroundStyle(AppTheme.reviewTextMuted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ReviewHistoryDrilldownPeekContainer(
                        above: journalingDaysCaption,
                        abovePeekHeight: $abovePeekHeight,
                        grid: { peek in
                            ReviewHistoryDrilldownCalendarGrid(
                                matchingDayStarts: historyJournalDays,
                                journalDaysInHistoryWindow: historyJournalDays,
                                historyDayRange: historyDayRange,
                                displayRange: displayRange,
                                calendar: drilldownCalendar,
                                growthStageForMatchedDays: nil,
                                sectionStripChipCountsByDay: nil,
                                scrollViewportHeight: peek,
                                onMatchingDaySelected: { day in
                                    journalNavigationDay = ReviewHistoryDrilldownJournalNavigationDay(
                                        dayStart: day,
                                        calendar: drilldownCalendar
                                    )
                                }
                            )
                            .padding(.vertical, 4)
                        }
                    )
                }
            }
            .background(AppTheme.reviewBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(String(localized: "Reflection rhythm"))
                        .font(AppTheme.warmPaperBody.weight(.semibold))
                        .foregroundStyle(AppTheme.reviewTextPrimary)
                        .accessibilityIdentifier("ReviewHistoryJournalingDaysDrilldownTitle")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PastToolbarDoneButton(
                        action: { dismiss() },
                        symbol: .xmark,
                        accessibilityIdentifier: "ReviewHistoryJournalingDaysDrilldownDone"
                    )
                }
            }
            .navigationDestination(item: $journalNavigationDay) { item in
                JournalScreen(entryDate: item.date)
            }
        }
    }

    private var journalingDaysCaption: some View {
        Text(String(localized: "Review history journaling days drilldown caption"))
            .font(AppTheme.warmPaperMeta)
            .foregroundStyle(AppTheme.reviewTextMuted)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

// MARK: - Growth stage

private struct GrowthStageDrilldownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var journalNavigationDay: ReviewHistoryDrilldownJournalNavigationDay?
    @State private var abovePeekHeight: CGFloat = 0

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
            Group {
                if matchingDayStarts.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            growthStageCriterionCaption
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
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ReviewHistoryDrilldownPeekContainer(
                        above: growthStageCriterionCaption,
                        abovePeekHeight: $abovePeekHeight,
                        grid: { peek in
                            ReviewHistoryDrilldownCalendarGrid(
                                matchingDayStarts: matchingDayStarts,
                                journalDaysInHistoryWindow: historyJournalDays,
                                historyDayRange: historyDayRange,
                                displayRange: displayRange,
                                calendar: drilldownCalendar,
                                growthStageForMatchedDays: level,
                                sectionStripChipCountsByDay: nil,
                                scrollViewportHeight: peek,
                                onMatchingDaySelected: { day in
                                    journalNavigationDay = ReviewHistoryDrilldownJournalNavigationDay(
                                        dayStart: day,
                                        calendar: drilldownCalendar
                                    )
                                }
                            )
                            .padding(.vertical, 4)
                        }
                    )
                }
            }
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(growthStageDisplayTitle(for: level)). \(growthStageCriterion(for: level))"
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PastToolbarDoneButton(action: { dismiss() }, symbol: .xmark)
                }
            }
            .navigationDestination(item: $journalNavigationDay) { item in
                JournalScreen(entryDate: item.date)
            }
        }
    }

    /// Criterion lives here (not in ``ToolbarItem/placement/principal``) so it can wrap without clipping the nav bar.
    private var growthStageCriterionCaption: some View {
        Text(growthStageCriterion(for: level))
            .font(AppTheme.warmPaperMeta)
            .foregroundStyle(AppTheme.reviewTextMuted)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
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
                    ReviewHistoryDrilldownPeekContainer(
                        above: Color.clear.frame(height: 0),
                        abovePeekHeight: .constant(0),
                        aboveAndGridSpacing: 0,
                        grid: { peek in
                            ReviewHistoryDrilldownCalendarGrid(
                                matchingDayStarts: sectionMatchingDayStarts,
                                journalDaysInHistoryWindow: historyJournalDays,
                                historyDayRange: historyDayRange,
                                displayRange: displayRange,
                                calendar: drilldownCalendar,
                                growthStageForMatchedDays: nil,
                                sectionStripChipCountsByDay: sectionStripChipCountsByDay,
                                scrollViewportHeight: peek,
                                onMatchingDaySelected: { day in
                                    journalNavigationDay = ReviewHistoryDrilldownJournalNavigationDay(
                                        dayStart: day,
                                        calendar: drilldownCalendar
                                    )
                                }
                            )
                            .padding(.vertical, 4)
                        }
                    )
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
                    PastToolbarDoneButton(action: { dismiss() }, symbol: .xmark)
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
