import Foundation

/// Shared history-window and per-day completion semantics for Past statistics (issue #169).
enum ReviewHistoryWindowing {
    static func sortedEntries(_ entries: [JournalEntry]) -> [JournalEntry] {
        entries.sorted {
            if $0.entryDate != $1.entryDate {
                return $0.entryDate < $1.entryDate
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    static func entriesInValidatedHistoryWindow(
        allEntries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) -> [JournalEntry] {
        let sortedAll = sortedEntries(allEntries)
        let historyRange = pastStatisticsInterval.validated.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: allEntries
        )
        return sortedAll.filter { entry in
            let day = calendar.startOfDay(for: entry.entryDate)
            return day >= historyRange.lowerBound && day < historyRange.upperBound
        }
    }

    /// Strongest completion level per calendar day (same rules as ``WeeklyReviewAggregatesBuilder`` / skyline mix).
    static func strongestCompletionByDay(
        from entries: [JournalEntry],
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
        in entriesSortedOldestFirst: [JournalEntry]
    ) -> [JournalEntry] {
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
}
