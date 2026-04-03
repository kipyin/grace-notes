import Foundation

struct ReviewInsightsRefreshKey: Hashable {
    let weekStart: Date
    let entrySnapshots: [ReviewEntrySnapshot]
    let weekBoundaryPreferenceRawValue: String
    let pastStatisticsIntervalToken: String

    init(
        weekStart: Date,
        entrySnapshots: [ReviewEntrySnapshot],
        weekBoundaryPreferenceRawValue: String = ReviewWeekBoundaryPreference.defaultValue.rawValue,
        pastStatisticsIntervalToken: String = PastStatisticsIntervalSelection.default.cacheKeyToken
    ) {
        self.weekStart = weekStart
        self.entrySnapshots = entrySnapshots
        self.weekBoundaryPreferenceRawValue = weekBoundaryPreferenceRawValue
        self.pastStatisticsIntervalToken = pastStatisticsIntervalToken
    }

    /// Snapshots for every loaded entry that can change Past-tab insights: the resolved past-statistics
    /// window plus the current and previous review weeks (trend comparison).
    static func entrySnapshotsAffectingInsights(
        entries: [Journal],
        referenceDate: Date,
        calendar: Calendar,
        pastStatisticsInterval: PastStatisticsIntervalSelection,
        currentReviewPeriod: Range<Date>
    ) -> [ReviewEntrySnapshot] {
        let historyRange = pastStatisticsInterval.validated.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: entries
        )
        let previousPeriod = ReviewInsightsPeriod.previousPeriod(
            before: currentReviewPeriod,
            calendar: calendar
        )
        let snapshots = entries.compactMap { entry -> ReviewEntrySnapshot? in
            let entryDay = calendar.startOfDay(for: entry.entryDate)
            let inHistoryWindow = entryDay >= historyRange.lowerBound && entryDay < historyRange.upperBound
            let inCurrentWeek = currentReviewPeriod.contains(entry.entryDate)
            let inPreviousWeek = previousPeriod.contains(entry.entryDate)
            guard inHistoryWindow || inCurrentWeek || inPreviousWeek else { return nil }
            return ReviewEntrySnapshot(id: entry.id, updatedAt: entry.updatedAt)
        }
        return snapshots.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

struct ReviewEntrySnapshot: Hashable {
    let id: UUID
    let updatedAt: Date
}

enum ReviewInsightsRefreshPolicy {
    static func shouldRefresh(
        hasInsights: Bool,
        previousKey: ReviewInsightsRefreshKey?,
        currentKey: ReviewInsightsRefreshKey
    ) -> Bool {
        if !hasInsights {
            return true
        }
        return previousKey != currentKey
    }

    /// Matches the final fallback `ReviewInsights` in `ReviewInsightsProvider` when deterministic
    /// generation fails.
    static func isSparseProviderFallback(_ insights: ReviewInsights) -> Bool {
        guard insights.source == .deterministic,
              insights.narrativeSummary == nil,
              insights.recurringGratitudes.isEmpty,
              insights.recurringNeeds.isEmpty,
              insights.recurringPeople.isEmpty,
              insights.weeklyInsights.count == 1
        else {
            return false
        }
        let only = insights.weeklyInsights[0]
        return only.pattern == .sparseFallback
            && only.primaryTheme == nil
            && only.mentionCount == nil
            && only.dayCount == 0
    }
}
