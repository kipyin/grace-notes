import Foundation

struct ReviewInsightsRefreshKey: Hashable {
    let weekStart: Date
    let entrySnapshots: [ReviewEntrySnapshot]
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
