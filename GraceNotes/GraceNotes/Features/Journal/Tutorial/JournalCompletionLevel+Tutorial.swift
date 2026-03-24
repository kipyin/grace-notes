import Foundation

extension JournalCompletionLevel {
    /// Monotonic rank for tutorial milestones (matches `JournalScreen` completion progression).
    var tutorialCompletionRank: Int {
        switch self {
        case .soil:
            return 0
        case .seed:
            return 1
        case .ripening:
            return 2
        case .harvest:
            return 3
        case .abundance:
            return 4
        }
    }
}
