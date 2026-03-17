import Foundation

struct ReviewInsightsRefreshKey: Hashable {
    let weekStart: Date
    let useAIReviewInsights: Bool
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
}
