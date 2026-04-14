import Foundation

/// Persisted Today tab journal chrome (`Standard` vs `Bloom`). Scoped to Today-only in the UI.
enum JournalAppearanceMode: String, CaseIterable, Identifiable {
    case standard
    case bloom

    var id: String { rawValue }

    /// Interprets persisted `@AppStorage` / `UserDefaults` strings, including legacy `"summer"`.
    /// Trims surrounding whitespace and lowercases before matching so hand-edited or oddly-cased values do not silently fall back to Standard.
    static func resolveStored(rawValue: String) -> JournalAppearanceMode {
        let normalized = normalizedStoredRawValue(rawValue)
        if normalized == "summer" {
            return .bloom
        }
        return JournalAppearanceMode(rawValue: normalized) ?? .standard
    }

    /// Rewrites legacy `"summer"` to ``bloom``’s raw value so new exports and debugging stay canonical.
    static func migrateLegacyJournalAppearanceRawValueIfNeeded(defaults: UserDefaults = .standard) {
        let key = JournalAppearanceStorageKeys.todayMode
        guard let stored = defaults.string(forKey: key) else { return }
        guard normalizedStoredRawValue(stored) == "summer" else { return }
        defaults.set(JournalAppearanceMode.bloom.rawValue, forKey: key)
    }

    private static func normalizedStoredRawValue(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum JournalAppearanceStorageKeys {
    static let todayMode = "journalTodayAppearanceMode"
}
