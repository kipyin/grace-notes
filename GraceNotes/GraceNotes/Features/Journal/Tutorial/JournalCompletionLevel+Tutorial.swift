import Foundation

extension JournalCompletionLevel {
    /// Monotonic rank for tutorial milestones (matches `JournalScreen` completion progression).
    var tutorialCompletionRank: Int {
        switch self {
        case .empty:
            return 0
        case .started:
            return 1
        case .growing:
            return 2
        case .balanced:
            return 3
        case .full:
            return 4
        }
    }
}
