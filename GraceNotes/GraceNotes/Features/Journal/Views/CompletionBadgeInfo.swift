import Foundation

enum CompletionBadgeInfo: Equatable {
    case empty
    case started
    case growing
    case balanced
    case full

    var title: String {
        switch self {
        case .empty:
            return String(localized: "journal.growthStage.empty")
        case .started:
            return String(localized: "journal.growthStage.started")
        case .growing:
            return String(localized: "journal.growthStage.growing")
        case .balanced:
            return String(localized: "journal.growthStage.balanced")
        case .full:
            return String(localized: "journal.growthStage.full")
        }
    }

    // swiftlint:disable line_length
    var description: String {
        switch self {
        case .empty:
            return String(localized: "journal.guidance.moveToSprout")
        case .started:
            return String(localized: "journal.guidance.enterTwig")
        case .growing:
            return String(localized: "journal.guidance.towardLeaf")
        case .balanced:
            return String(localized: "journal.guidance.allSectionsThreeTowardBloom")
        case .full:
            return String(localized: "journal.guidance.allSectionsCompleteToday")
        }
    }
    // swiftlint:enable line_length
}
