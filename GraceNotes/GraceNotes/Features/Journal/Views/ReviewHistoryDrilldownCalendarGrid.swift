import SwiftUI

// MARK: - Section strip (read-only)

private struct ReviewHistorySectionStripDots: View {
    let filledCount: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<Journal.slotCount, id: \.self) { index in
                let isFilled = index < filledCount
                Circle()
                    .fill(isFilled ? AppTheme.journalComplete : Color.clear)
                    .frame(width: 5, height: 5)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                AppTheme.journalPendingOutline.opacity(isFilled ? 0 : 0.45),
                                lineWidth: 1
                            )
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Grid

// Continuous week grid for Growth / Section drill-downs (week header, month banners, one week per row).
// swiftlint:disable type_body_length
struct ReviewHistoryDrilldownCalendarGrid: View {
    enum Metrics {
        /// Roughly 1.5 months of vertical space for the scrolling region (issue #186).
        static let scrollViewportHeight: CGFloat = 396
        /// Fraction of masked viewport height where the top feather reaches full opacity (matches gradient stop).
        static let featherOpaqueStartsAt: CGFloat = 0.07
        /// Fraction where bottom feather begins (matches gradient stop).
        static let featherOpaqueEndsAt: CGFloat = 0.93
        /// Keeps the last week row clear of the bottom feather when scrolled to the end.
        static let scrollContentBottomInset: CGFloat = 36
        /// Avoid y: 1 — it pins the week row into the bottom feather on first layout; lower-mid band stays clear.
        static let scrollLatestMatchAnchor = UnitPoint(x: 0.5, y: 0.56)
    }

    static func scrollContentTopInset(forViewportHeight viewportHeight: CGFloat) -> CGFloat {
        (viewportHeight * Metrics.featherOpaqueStartsAt).rounded(.up)
    }

    let matchingDayStarts: Set<Date>
    let journalDaysInHistoryWindow: Set<Date>
    let historyDayRange: Range<Date>
    let displayRange: Range<Date>
    let calendar: Calendar
    let growthStageForMatchedDays: JournalCompletionLevel?
    let sectionStripChipCountsByDay: [Date: Int]?
    var scrollViewportHeight: CGFloat = Metrics.scrollViewportHeight
    let onMatchingDaySelected: (Date) -> Void

    @State private var scrollPositionRowID: String?

    private var rows: [ReviewHistoryDrilldownCalendarRow] {
        ReviewHistoryDrilldownCalendarLayout.continuousRows(displayRange: displayRange, calendar: calendar)
    }

    private var orderedWeekdaySymbols: [String] {
        ReviewHistoryDrilldownCalendarLayout.weekdaySymbolsOrdered(calendar: calendar)
    }

    /// Week row id for the chronologically latest matching day; drives initial `scrollPosition`.
    private var latestMatchWeekRowID: String? {
        guard let latest = matchingDayStarts.max(),
              let rowId = ReviewHistoryDrilldownCalendarLayout.weekRowIdContaining(
                dayStart: latest,
                rows: rows,
                calendar: calendar
              )
        else {
            return nil
        }
        return rowId
    }

    private var calendarDayFeatherMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: Metrics.featherOpaqueStartsAt),
                .init(color: .black, location: Metrics.featherOpaqueEndsAt),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(AppTheme.warmPaperCaption)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(
                    format: String(localized: "past.drilldown.calendarWeekdaysRow.a11y"),
                    orderedWeekdaySymbols.joined(separator: ", ")
                )
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { row in
                        Group {
                            switch row {
                            case .monthBanner(_, let title):
                                Text(title)
                                    .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                                    .foregroundStyle(AppTheme.reviewTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityAddTraits(.isHeader)
                            case .week(_, let cells):
                                calendarWeekRow(cells: cells)
                            }
                        }
                        .id(row.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, Self.scrollContentTopInset(forViewportHeight: scrollViewportHeight))
                .padding(.bottom, Metrics.scrollContentBottomInset)
            }
            .scrollPosition(id: $scrollPositionRowID, anchor: Metrics.scrollLatestMatchAnchor)
            .frame(maxHeight: scrollViewportHeight)
            .mask(calendarDayFeatherMask)
            .task(id: latestMatchWeekRowID) {
                scrollPositionRowID = latestMatchWeekRowID
            }
        }
    }

    private func calendarWeekRow(cells: [Date?]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cellDay in
                dayCell(cellDay)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cellDay: Date?) -> some View {
        if let dayStart = cellDay {
            let disposition = ReviewHistoryDrilldownDayDisposition.resolve(
                dayStart: dayStart,
                historyDayRange: historyDayRange,
                journalDaysInHistoryWindow: journalDaysInHistoryWindow,
                matchingDayStarts: matchingDayStarts
            )
            let dayNumber = calendar.component(.day, from: dayStart)
            let dateSpeech = dayStart.formatted(date: .complete, time: .omitted)

            if disposition == .outsideHistoryWindow {
                matchedDayLabel(dayNumber: dayNumber, dayStart: dayStart, disposition: disposition)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        nonMatchedAccessibilityLabel(dateSpeech: dateSpeech, disposition: disposition)
                    )
                    .accessibilityHint(nonMatchedAccessibilityHint(disposition: disposition))
            } else {
                Button {
                    onMatchingDaySelected(dayStart)
                } label: {
                    matchedDayLabel(
                        dayNumber: dayNumber,
                        dayStart: dayStart,
                        disposition: disposition
                    )
                }
                .buttonStyle(PastTappablePressStyle())
                .accessibilityLabel(dayCellAccessibilityLabel(dateSpeech: dateSpeech, disposition: disposition))
                .accessibilityHint(dayCellButtonAccessibilityHint(disposition: disposition))
            }
        } else {
            Color.clear
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func matchedDayLabel(
        dayNumber: Int,
        dayStart: Date,
        disposition: ReviewHistoryDrilldownDayDisposition
    ) -> some View {
        let stripCount = sectionStripChipCountsByDay?[dayStart]
        let growthLevel = growthStageForMatchedDays
        let showSectionStrip = disposition == .matched && stripCount != nil

        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .monospacedDigit()
                .font(textFont(disposition: disposition, matched: disposition == .matched))
                .foregroundStyle(textColor(disposition: disposition))

            if showSectionStrip, let stripCount {
                ReviewHistorySectionStripDots(filledCount: stripCount)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, showSectionStrip ? 2 : 0)
        .background {
            cellBackground(disposition: disposition, growthLevel: growthLevel)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    cellBorderColor(disposition: disposition, growthLevel: growthLevel),
                    lineWidth: cellBorderWidth(disposition: disposition)
                )
        }
        .shadow(
            color: cellShadow(disposition: disposition, growthLevel: growthLevel),
            radius: 3,
            x: 0,
            y: 1.2
        )
    }

    private func textFont(disposition: ReviewHistoryDrilldownDayDisposition, matched: Bool) -> Font {
        let emphasizes = matched || disposition == .journalDayNotMatched
        return emphasizes ? AppTheme.warmPaperBody.weight(.semibold) : AppTheme.warmPaperBody
    }

    private func textColor(disposition: ReviewHistoryDrilldownDayDisposition) -> Color {
        switch disposition {
        case .matched:
            return AppTheme.reviewTextPrimary
        case .journalDayNotMatched:
            return AppTheme.reviewTextPrimary.opacity(0.92)
        case .emptyHistoryDay:
            return AppTheme.reviewTextMuted.opacity(0.62)
        case .outsideHistoryWindow:
            return AppTheme.reviewTextMuted.opacity(0.48)
        }
    }

    @ViewBuilder
    private func cellBackground(
        disposition: ReviewHistoryDrilldownDayDisposition,
        growthLevel: JournalCompletionLevel?
    ) -> some View {
        switch disposition {
        case .matched:
            if let level = growthLevel {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.reviewRhythmPillBackground(for: level))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.reviewPaper.opacity(0.88))
            }
        case .journalDayNotMatched:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.reviewPaper.opacity(0.42))
        case .emptyHistoryDay, .outsideHistoryWindow:
            EmptyView()
        }
    }

    private func cellBorderColor(
        disposition: ReviewHistoryDrilldownDayDisposition,
        growthLevel: JournalCompletionLevel?
    ) -> Color {
        switch disposition {
        case .matched:
            if let level = growthLevel {
                return AppTheme.reviewRhythmPillBorder(for: level)
            }
            return AppTheme.reviewStandardBorder.opacity(0.42)
        case .journalDayNotMatched:
            return AppTheme.reviewStandardBorder.opacity(0.28)
        case .emptyHistoryDay:
            return AppTheme.reviewStandardBorder.opacity(0.12)
        case .outsideHistoryWindow:
            return Color.clear
        }
    }

    private func cellBorderWidth(disposition: ReviewHistoryDrilldownDayDisposition) -> CGFloat {
        switch disposition {
        case .matched, .journalDayNotMatched, .emptyHistoryDay:
            return 1
        case .outsideHistoryWindow:
            return 0
        }
    }

    private func cellShadow(
        disposition: ReviewHistoryDrilldownDayDisposition,
        growthLevel: JournalCompletionLevel?
    ) -> Color {
        guard disposition == .matched, let level = growthLevel else {
            return .clear
        }
        return AppTheme.reviewRhythmPillShadow(for: level)
    }

    private func dayCellAccessibilityLabel(
        dateSpeech: String,
        disposition: ReviewHistoryDrilldownDayDisposition
    ) -> String {
        if disposition == .matched {
            return String(
                format: String(localized: "past.drilldown.calendarDay.a11y.matchedFormat"),
                dateSpeech
            )
        }
        return nonMatchedAccessibilityLabel(dateSpeech: dateSpeech, disposition: disposition)
    }

    private func nonMatchedAccessibilityLabel(
        dateSpeech: String,
        disposition: ReviewHistoryDrilldownDayDisposition
    ) -> String {
        switch disposition {
        case .journalDayNotMatched:
            return String(
                format: String(localized: "past.drilldown.calendarDay.a11y.journalNotMatchedFormat"),
                dateSpeech
            )
        case .emptyHistoryDay:
            return String(
                format: String(localized: "past.drilldown.calendarDay.a11y.emptyFormat"),
                dateSpeech
            )
        case .outsideHistoryWindow:
            return String(
                format: String(localized: "past.drilldown.calendarDay.a11y.outsideRangeFormat"),
                dateSpeech
            )
        case .matched:
            return dateSpeech
        }
    }

    private func nonMatchedAccessibilityHint(disposition: ReviewHistoryDrilldownDayDisposition) -> String {
        switch disposition {
        case .journalDayNotMatched:
            return String(localized: "past.drilldown.calendarDay.a11yHint.journalNotMatched")
        case .emptyHistoryDay:
            return String(localized: "past.drilldown.calendarDay.a11yHint.emptyHistoryDay")
        case .outsideHistoryWindow:
            return String(localized: "past.drilldown.calendarDay.a11yHint.outsideStatisticsRange")
        case .matched:
            return ""
        }
    }

    /// VoiceOver hint for tappable in-range days (empty days are not “open existing entry”).
    /// Only used from the `Button` branch in `dayCell`; outside-window days take the non-button path.
    private func dayCellButtonAccessibilityHint(disposition: ReviewHistoryDrilldownDayDisposition) -> String {
        switch disposition {
        case .emptyHistoryDay:
            return String(localized: "past.accessibility.openDayToWrite")
        case .matched, .journalDayNotMatched:
            return String(localized: "past.accessibility.openEntryThatDay")
        case .outsideHistoryWindow:
            fatalError("dayCellButtonAccessibilityHint: outside-window cells use the non-button path in dayCell.")
        }
    }
}
// swiftlint:enable type_body_length
