import Foundation

/// Persisted Today tab journal chrome (`Standard` vs `Bloom`). Scoped to Today-only in the UI.
enum JournalAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case standard
    case bloom

    var id: String { rawValue }

    /// Interprets persisted `@AppStorage` / `UserDefaults` strings, including legacy `"summer"`.
    /// Trims surrounding whitespace and lowercases before matching so hand-edited or oddly-cased values do not
    /// silently fall back to Standard.
    static func resolveStored(rawValue: String) -> JournalAppearanceMode {
        let normalized = normalizedStoredRawValue(rawValue)
        if normalized == "summer" {
            return .bloom
        }
        return JournalAppearanceMode(rawValue: normalized) ?? .standard
    }

    /// Rewrites legacy `"summer"` to ``bloom``’s raw value so new exports and debugging stay canonical.
    /// Persists the canonical raw value whenever the stored string differs from that form (odd casing,
    /// surrounding whitespace, unknown values, etc.).
    static func migrateLegacyJournalAppearanceRawValueIfNeeded(defaults: UserDefaults = .standard) {
        let key = JournalAppearanceStorageKeys.todayMode
        let stored: String
        if let string = defaults.string(forKey: key) {
            stored = string
        } else if defaults.object(forKey: key) != nil {
            // `string(forKey:)` is nil for non-string values; `@AppStorage` expects a string. Resolve as empty.
            stored = ""
        } else {
            return
        }
        let resolved = resolveStored(rawValue: stored)
        let canonical = resolved.rawValue
        guard stored != canonical else { return }
        defaults.set(canonical, forKey: key)
    }

    private static func normalizedStoredRawValue(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum JournalAppearanceStorageKeys {
    static let todayMode = "journalTodayAppearanceMode"
}
