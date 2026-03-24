import Foundation

extension JournalCompletionLevel {
    /// SF Symbol paired with completion status labels (matches ``JournalCompletionPill``).
    func completionStatusSystemImage(isEmphasized: Bool) -> String {
        switch self {
        case .soil:
            return "circle.dotted"
        case .seed:
            return isEmphasized ? "leaf.fill" : "leaf"
        case .ripening:
            return isEmphasized ? "tree.fill" : "tree"
        case .harvest:
            return "sparkles"
        case .abundance:
            return isEmphasized ? "sun.max.fill" : "sun.max"
        }
    }
}
