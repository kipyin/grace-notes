import Foundation

/// Shared history-window and per-day completion semantics for Past statistics (issue #169).
enum ReviewHistoryWindowing {
    static func sortedEntries(_ entries: [Journal]) -> [Journal] {
        entries.sorted {
            if $0.entryDate != $1.entryDate {
                return $0.entryDate < $1.entryDate
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    static func entriesInValidatedHistoryWindow(
        allEntries: [Journal],
        referenceDate: Date,
        calendar: Calendar,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) -> [Journal] {
        let historyRange = pastStatisticsInterval.validated.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: allEntries
        )
        let inWindow = allEntries.filter { entry in
            let day = calendar.startOfDay(for: entry.entryDate)
            return day >= historyRange.lowerBound && day < historyRange.upperBound
        }
        return sortedEntries(inWindow)
    }

    /// Strongest completion level per calendar day (same rules as ``WeeklyReviewAggregatesBuilder`` / skyline mix).
    static func strongestCompletionByDay(
        from entries: [Journal],
        calendar: Calendar
    ) -> [Date: JournalCompletionLevel] {
        var strongestByDay: [Date: JournalCompletionLevel] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            let current = strongestByDay[day]
            if let current, completionRank(current) >= completionRank(entry.completionLevel) {
                continue
            }
            strongestByDay[day] = entry.completionLevel
        }
        return strongestByDay
    }

    static func calendarDaysMatchingStrongestCompletionLevel(
        _ level: JournalCompletionLevel,
        strongestByDay: [Date: JournalCompletionLevel]
    ) -> [Date] {
        strongestByDay.compactMap { day, strongestLevel in
            strongestLevel == level ? day : nil
        }.sorted { $0 > $1 }
    }

    /// Entries with at least one item in the section; newest first (issue #169 section drill-down).
    static func entriesContributingToSection(
        _ section: ReviewStatsSectionKind,
        in entriesSortedOldestFirst: [Journal]
    ) -> [Journal] {
        let filtered = entriesSortedOldestFirst.filter { entry in
            switch section {
            case .gratitudes:
                !(entry.gratitudes ?? []).isEmpty
            case .needs:
                !(entry.needs ?? []).isEmpty
            case .people:
                !(entry.people ?? []).isEmpty
            }
        }
        return filtered.sorted {
            if $0.entryDate != $1.entryDate {
                return $0.entryDate > $1.entryDate
            }
            return $0.id.uuidString > $1.id.uuidString
        }
    }

    private static func completionRank(_ level: JournalCompletionLevel) -> Int {
        level.tutorialCompletionRank
    }

    /// Calendar days (start-of-day) that have at least one journal in the already-filtered history slice.
    static func journalEntryDayStarts(
        fromHistoryEntries entries: [Journal],
        calendar: Calendar
    ) -> Set<Date> {
        Set(entries.map { calendar.startOfDay(for: $0.entryDate) })
    }

    /// Per-day chip count for the given section (capped at ``Journal.slotCount``), one dot strip per matched day.
    /// When multiple contributing entries share a day, uses the newest (``entriesContributingToSection`` order).
    static func sectionChipCountByMatchedDays(
        section: ReviewStatsSectionKind,
        matchingDayStarts: Set<Date>,
        contributingEntriesNewestFirst: [Journal],
        calendar: Calendar
    ) -> [Date: Int] {
        // One pass: first row per calendar day matches `first(where:)` (see drill-down tests).
        var firstContributingByDay: [Date: Journal] = [:]
        firstContributingByDay.reserveCapacity(contributingEntriesNewestFirst.count)
        for entry in contributingEntriesNewestFirst {
            let day = calendar.startOfDay(for: entry.entryDate)
            if firstContributingByDay[day] == nil {
                firstContributingByDay[day] = entry
            }
        }

        var result: [Date: Int] = [:]
        result.reserveCapacity(matchingDayStarts.count)
        for day in matchingDayStarts {
            guard let journal = firstContributingByDay[day] else {
                continue
            }
            let raw: Int
            switch section {
            case .gratitudes:
                raw = (journal.gratitudes ?? []).count
            case .needs:
                raw = (journal.needs ?? []).count
            case .people:
                raw = (journal.people ?? []).count
            }
            result[day] = min(Journal.slotCount, max(0, raw))
        }
        return result
    }
}
