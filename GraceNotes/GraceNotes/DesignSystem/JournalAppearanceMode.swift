import Foundation

/// Persisted Today tab journal chrome (`Standard` vs `Bloom`). Scoped to Today-only in the UI.
enum JournalAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case standard
    case bloom

    var id: String { rawValue }

    /// Interprets persisted `@AppStorage` / `UserDefaults` strings, including legacy `"summer"`.
    /// Trims surrounding whitespace and lowercases before matching so hand-edited or oddly-cased values
    /// still resolve to ``bloom`` or ``standard`` when the meaning is clear. Unknown strings become
    /// ``standard``.
    static func resolveStored(rawValue: String) -> JournalAppearanceMode {
        let normalized = normalizedStoredRawValue(rawValue)
        if normalized == legacySummerStoredRawValue {
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

    private static let legacySummerStoredRawValue = "summer"
    /// Locale used for lowercasing stored keys so casing matches do not depend on the user's
    /// language/region settings (identifier-style strings, not prose).
    private static let storedKeyLocale = Locale(identifier: "en_US_POSIX")

    private static func normalizedStoredRawValue(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: storedKeyLocale)
    }
}

enum JournalAppearanceStorageKeys {
    static let todayMode = "journalTodayAppearanceMode"
}
