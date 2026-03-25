import Foundation

/// Persists the last successful weekly `ReviewInsights` per week start (local calendar day) so a cold launch
/// can show stale content while regeneration runs.
actor ReviewInsightsCache {
    private static let payloadKey = "GraceNotes.reviewInsightsByWeek.v1"
    private static let maxWeekEntries = 8

    private struct Payload: Codable {
        var weeks: [Double: ReviewInsights]
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    static let shared = ReviewInsightsCache()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func insights(forWeekStart weekStart: Date, calendar: Calendar) -> ReviewInsights? {
        let key = Self.normalizedWeekStartInterval(weekStart, calendar: calendar)
        guard let payload = loadPayload() else {
            return nil
        }
        return payload.weeks[key]
    }

    func storeIfEligible(_ insights: ReviewInsights, calendar: Calendar) {
        guard !ReviewInsightsRefreshPolicy.isSparseProviderFallback(insights) else {
            return
        }
        let key = Self.normalizedWeekStartInterval(insights.weekStart, calendar: calendar)
        var payload = loadPayload() ?? Payload(weeks: [:])
        payload.weeks[key] = insights
        payload.weeks = Self.prune(weeks: payload.weeks, keepingMostRecent: Self.maxWeekEntries)
        savePayload(payload)
    }

    func clearAllForTesting() {
        userDefaults.removeObject(forKey: Self.payloadKey)
    }

    private func loadPayload() -> Payload? {
        guard let data = userDefaults.data(forKey: Self.payloadKey) else {
            return nil
        }
        do {
            return try decoder.decode(Payload.self, from: data)
        } catch {
            userDefaults.removeObject(forKey: Self.payloadKey)
            return nil
        }
    }

    private func savePayload(_ payload: Payload) {
        guard let data = try? encoder.encode(payload) else {
            return
        }
        userDefaults.set(data, forKey: Self.payloadKey)
    }

    private static func normalizedWeekStartInterval(_ date: Date, calendar: Calendar) -> Double {
        calendar.startOfDay(for: date).timeIntervalSince1970
    }

    private static func prune(
        weeks: [Double: ReviewInsights],
        keepingMostRecent: Int
    ) -> [Double: ReviewInsights] {
        guard weeks.count > keepingMostRecent else {
            return weeks
        }
        let sortedKeys = weeks.keys.sorted(by: >).prefix(keepingMostRecent)
        let keysToKeep = Set(sortedKeys)
        return weeks.filter { keysToKeep.contains($0.key) }
    }
}
