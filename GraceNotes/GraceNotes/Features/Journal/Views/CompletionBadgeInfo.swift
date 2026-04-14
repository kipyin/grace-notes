import SwiftUI

enum CompletionBadgeInfo: Equatable, Sendable {
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

    var completionLevel: JournalCompletionLevel {
        switch self {
        case .empty:
            return .soil
        case .started:
            return .sprout
        case .growing:
            return .twig
        case .balanced:
            return .leaf
        case .full:
            return .bloom
        }
    }

    static func matching(_ level: JournalCompletionLevel) -> CompletionBadgeInfo {
        switch level {
        case .soil:
            return .empty
        case .sprout:
            return .started
        case .twig:
            return .growing
        case .leaf:
            return .balanced
        case .bloom:
            return .full
        }
    }

    func infoCardTintColor(using palette: TodayJournalPalette) -> Color {
        switch completionLevel {
        case .soil:
            return palette.textMuted
        case .sprout:
            return palette.quickCheckInText
        case .twig, .leaf:
            return palette.standardText
        case .bloom:
            return palette.fullText
        }
    }
}
