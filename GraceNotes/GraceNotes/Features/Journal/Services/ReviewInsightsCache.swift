import Foundation

/// Persists the last successful weekly `ReviewInsights` per week start (local calendar day) so a cold launch
/// can show stale content while regeneration runs.
///
/// Cache entries are keyed by **week start + week-boundary preference** so a boundary change cannot hydrate
/// aggregates that were computed under a different `Calendar.firstWeekday`.
///
/// **Codable evolution:** Payloads encode nested models (including ``ReviewWeekStats``) with `JSONEncoder`.
/// New ``ReviewWeekStats`` keys such as `historySectionTotals` and `historyCompletionMix` decode with
/// `decodeIfPresent`; when absent (caches written before those fields existed), decoding substitutes **empty**
/// history rollups (zero counts). That avoids failing the whole payload, but history UI should treat all-zero
/// history as **possibly stale** until `ReviewInsightsProvider` finishes a fresh ``generateInsights`` pass and
/// `storeIfEligible` persists updated stats—same pattern as optional `rhythmHistory` on older blobs.
actor ReviewInsightsCache {
    private static let payloadKey = "GraceNotes.reviewInsightsByWeek.v2"
    /// Obsolete payload from builds that keyed only by week start; stripped on load to avoid stale hydration.
    private static let legacyPayloadKey = "GraceNotes.reviewInsightsByWeek.v1"
    private static let maxWeekEntries = 8

    private struct Payload: Codable {
        var weeks: [String: ReviewInsights]
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    static let shared = ReviewInsightsCache()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func insights(
        forWeekStart weekStart: Date,
        calendar: Calendar,
        weekBoundaryPreferenceRawValue: String
    ) -> ReviewInsights? {
        let key = Self.compositeCacheKey(
            weekStart: weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: weekBoundaryPreferenceRawValue
        )
        guard let payload = loadPayload() else {
            return nil
        }
        return payload.weeks[key]
    }

    func storeIfEligible(
        _ insights: ReviewInsights,
        calendar: Calendar,
        weekBoundaryPreferenceRawValue: String
    ) {
        guard !ReviewInsightsRefreshPolicy.isSparseProviderFallback(insights) else {
            return
        }
        let key = Self.compositeCacheKey(
            weekStart: insights.weekStart,
            calendar: calendar,
            weekBoundaryPreferenceRawValue: weekBoundaryPreferenceRawValue
        )
        var payload = loadPayload() ?? Payload(weeks: [:])
        payload.weeks[key] = insights
        payload.weeks = Self.prune(weeks: payload.weeks, keepingMostRecent: Self.maxWeekEntries)
        savePayload(payload)
    }

    func clearAllForTesting() {
        userDefaults.removeObject(forKey: Self.payloadKey)
        userDefaults.removeObject(forKey: Self.legacyPayloadKey)
    }

    /// Synchronous wipe paired with `-grace-notes-reset-uitest-store` so a fresh SwiftData file does not
    /// hydrate stale `weekStats` from a previous session.
    nonisolated static func wipeDiskPayloadForUITestStoreReset() {
        UserDefaults.standard.removeObject(forKey: Self.payloadKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyPayloadKey)
    }

    private func loadPayload() -> Payload? {
        // v1 entries did not record boundary preference; never merge them into v2 reads.
        userDefaults.removeObject(forKey: Self.legacyPayloadKey)
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

    private static func compositeCacheKey(
        weekStart: Date,
        calendar: Calendar,
        weekBoundaryPreferenceRawValue: String
    ) -> String {
        let interval = normalizedWeekStartInterval(weekStart, calendar: calendar)
        return "\(interval)#\(weekBoundaryPreferenceRawValue)"
    }

    private static func weekInterval(fromCompositeCacheKey key: String) -> Double {
        guard let sep = key.firstIndex(of: "#") else {
            return 0
        }
        return Double(key[..<sep]) ?? 0
    }

    private static func prune(
        weeks: [String: ReviewInsights],
        keepingMostRecent: Int
    ) -> [String: ReviewInsights] {
        guard weeks.count > keepingMostRecent else {
            return weeks
        }
        let sortedKeys = weeks.keys
            .sorted {
                weekInterval(fromCompositeCacheKey: $0) > weekInterval(fromCompositeCacheKey: $1)
            }
            .prefix(keepingMostRecent)
        let keysToKeep = Set(sortedKeys)
        return weeks.filter { keysToKeep.contains($0.key) }
    }
}
