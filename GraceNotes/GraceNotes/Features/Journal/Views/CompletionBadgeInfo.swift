import Foundation

enum CompletionBadgeInfo: Equatable {
    case inProgress
    case seed
    case harvest

    var title: String {
        switch self {
        case .inProgress:
            return String(localized: "In Progress")
        case .seed:
            return String(localized: "Seed")
        case .harvest:
            return String(localized: "Harvest")
        }
    }

    var iconName: String {
        switch self {
        case .inProgress:
            return "pencil.circle"
        case .seed:
            return "leaf.fill"
        case .harvest:
            return "checkmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .inProgress:
            return String(localized: "In Progress means you can reach Seed by completing 1 gratitude, 1 need, and 1 person.")
        case .seed:
            return String(localized: "Seed means you reached 1 gratitude, 1 need, and 1 person. Continue your full reflection to reach Harvest.")
        case .harvest:
            return String(localized: "Harvest means you completed the full journal reflection for today.")
        }
    }
}
