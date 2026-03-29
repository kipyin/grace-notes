import Foundation

/// Persisted Today tab journal chrome (`Standard` vs `Summer`). Scoped to Today-only in the UI.
enum JournalAppearanceMode: String, CaseIterable, Identifiable {
    case standard
    case summer

    var id: String { rawValue }
}

enum JournalAppearanceStorageKeys {
    static let todayMode = "journalTodayAppearanceMode"
}
