import Foundation

struct ReviewInsightsRefreshKey: Hashable {
    let weekStart: Date
    let useCloudAI: Bool
    let entrySnapshots: [ReviewEntrySnapshot]
}

struct ReviewEntrySnapshot: Hashable {
    let id: UUID
    let updatedAt: Date
}

enum ReviewInsightsRefreshPolicy {
    static func shouldRefresh(
        force: Bool,
        hasInsights: Bool,
        previousKey: ReviewInsightsRefreshKey?,
        currentKey: ReviewInsightsRefreshKey
    ) -> Bool {
        if force || !hasInsights {
            return true
        }
        return previousKey != currentKey
    }

    /// Matches the final fallback `ReviewInsights` in `ReviewInsightsProvider` when cloud and deterministic
    /// generation both fail.
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

    /// Outcome of a pull-to-refresh (forced) insights regeneration.
    struct ForcedRefreshOutcome: Equatable {
        let insights: ReviewInsights
        /// When false, keep `lastInsightsRefreshKey` unchanged (discarded generated payload).
        let shouldUpdateCachedRefreshKey: Bool
    }

    static func forcedRefreshOutcome(previous: ReviewInsights?, generated: ReviewInsights) -> ForcedRefreshOutcome {
        guard let previous else {
            return ForcedRefreshOutcome(insights: generated, shouldUpdateCachedRefreshKey: true)
        }
        if isSparseProviderFallback(generated), !isSparseProviderFallback(previous) {
            return ForcedRefreshOutcome(insights: previous, shouldUpdateCachedRefreshKey: false)
        }
        return ForcedRefreshOutcome(insights: generated, shouldUpdateCachedRefreshKey: true)
    }
}
