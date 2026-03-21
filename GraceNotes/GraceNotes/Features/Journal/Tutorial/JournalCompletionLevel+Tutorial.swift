import Foundation

extension JournalCompletionLevel {
    /// Monotonic rank for tutorial milestones (matches `JournalScreen.rank(for:)`).
    var tutorialCompletionRank: Int {
        switch self {
        case .none:
            return 0
        case .quickCheckIn:
            return 1
        case .standardReflection:
            return 2
        case .fullFiveCubed:
            return 3
        }
    }
}
