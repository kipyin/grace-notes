import Foundation

/// Persisted Today tab journal chrome (`Standard` vs `Bloom`). Scoped to Today-only in the UI.
enum JournalAppearanceMode: String, CaseIterable, Identifiable {
    case standard
    case bloom

    var id: String { rawValue }

    /// Interprets persisted `@AppStorage` / `UserDefaults` strings, including legacy `"summer"`.
    static func resolveStored(rawValue: String) -> JournalAppearanceMode {
        if rawValue == "summer" {
            return .bloom
        }
        return JournalAppearanceMode(rawValue: rawValue) ?? .standard
    }

    /// Rewrites legacy `"summer"` to ``bloom``’s raw value so new exports and debugging stay canonical.
    static func migrateLegacyJournalAppearanceRawValueIfNeeded(defaults: UserDefaults = .standard) {
        let key = JournalAppearanceStorageKeys.todayMode
        guard defaults.string(forKey: key) == "summer" else { return }
        defaults.set(JournalAppearanceMode.bloom.rawValue, forKey: key)
    }
}

enum JournalAppearanceStorageKeys {
    static let todayMode = "journalTodayAppearanceMode"
}
