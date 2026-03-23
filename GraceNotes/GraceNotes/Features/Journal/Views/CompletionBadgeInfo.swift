import Foundation

enum CompletionBadgeInfo: Equatable {
    case soil
    case seed
    case ripening
    case harvest
    case abundance

    var title: String {
        switch self {
        case .soil:
            return String(localized: "Soil")
        case .seed:
            return String(localized: "Seed")
        case .ripening:
            return String(localized: "Ripening")
        case .harvest:
            return String(localized: "Harvest")
        case .abundance:
            return String(localized: "Abundance")
        }
    }

    var iconName: String {
        journalCompletionLevel.completionStatusSystemImage(isEmphasized: true)
    }

    private var journalCompletionLevel: JournalCompletionLevel {
        switch self {
        case .soil:
            return .soil
        case .seed:
            return .seed
        case .ripening:
            return .ripening
        case .harvest:
            return .harvest
        case .abundance:
            return .abundance
        }
    }

    // swiftlint:disable line_length
    var description: String {
        switch self {
        case .soil:
            return String(localized: "Soil means you have not yet added at least one gratitude, one need, and one person.")
        case .seed:
            return String(localized: "Seed means each section has at least one item, and you are still building toward three in each section.")
        case .ripening:
            return String(
                localized: "Ripening means you have at least three items in each section. Keep going to fill all five slots in each section to reach Harvest."
            )
        case .harvest:
            return String(
                localized: "Harvest means every spot is filled—five gratitudes, five needs, and five people. Add reading notes and reflections to reach Abundance."
            )
        case .abundance:
            return String(
                localized: "Abundance means every spot is filled in Gratitudes, Needs, and People, and you have added reading notes and reflections for today."
            )
        }
    }
    // swiftlint:enable line_length
}
