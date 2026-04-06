import Foundation
import SwiftUI

/// User-chosen accent for interaction chrome (tab tint, toggles, primary actions).
/// Body paper and tier greens stay stable.
enum AccentPreference: String, CaseIterable, Identifiable {
    case terracotta
    case forest

    var id: String { rawValue }

    static func resolveStored(rawValue: String) -> AccentPreference {
        AccentPreference(rawValue: rawValue) ?? .terracotta
    }

    /// Rewrites removed preset raw values (`ocean`, `plum`) so storage stays canonical.
    static func migrateRemovedCasesIfNeeded(defaults: UserDefaults = .standard) {
        let key = JournalAppearanceStorageKeys.accentPreference
        guard let raw = defaults.string(forKey: key) else { return }
        guard raw == "ocean" || raw == "plum" else { return }
        defaults.set(AccentPreference.terracotta.rawValue, forKey: key)
    }

    var localizedTitle: String {
        switch self {
        case .terracotta:
            return String(localized: "Settings.advanced.accent.terracotta")
        case .forest:
            return String(localized: "Settings.advanced.accent.forest")
        }
    }
}

enum JournalAppearanceStorageKeys {
    static let todayMode = "journalTodayAppearanceMode"
    static let accentPreference = "journalAccentPreference"
}
