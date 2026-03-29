import Foundation

/// Persisted Today tab journal chrome (`Standard` vs `Summer`). Scoped to Today-only in the UI.
enum JournalAppearanceMode: String, CaseIterable, Identifiable {
    case standard
    case summer

    var id: String { rawValue }
}

/// How Summer-mode leaves are drawn when Reduce Motion is off.
enum JournalSummerLeavesRenderer: String, CaseIterable, Identifiable {
    case video
    case native

    var id: String { rawValue }
}

enum JournalAppearanceStorageKeys {
    static let todayMode = "journalTodayAppearanceMode"
    static let summerLeavesRenderer = "journalSummerLeavesRenderer"
}
