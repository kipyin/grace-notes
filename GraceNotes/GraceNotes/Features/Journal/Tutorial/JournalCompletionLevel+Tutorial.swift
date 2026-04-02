import Foundation

extension JournalCompletionLevel {
    /// Monotonic rank for tutorial milestones (matches `JournalScreen` completion progression).
    var tutorialCompletionRank: Int {
        switch self {
        case .soil:
            return 0
        case .sprout:
            return 1
        case .twig:
            return 2
        case .leaf:
            return 3
        case .bloom:
            return 4
        }
    }
}
