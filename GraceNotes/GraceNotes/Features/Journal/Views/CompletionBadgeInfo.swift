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
        switch self {
        case .soil:
            return "circle.dotted"
        case .seed:
            return "leaf.fill"
        case .ripening:
            return "leaf.circle.fill"
        case .harvest:
            return "checkmark.circle.fill"
        case .abundance:
            return "sparkles"
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
            return String(localized: "Ripening means you have at least three in each section. Keep going to fill all five spots in every section for Harvest.")
        case .harvest:
            return String(localized: "Harvest means all gratitude, need, and people spots are filled. Add reading notes and reflections to reach Abundance.")
        case .abundance:
            return String(localized: "Abundance means you completed every chip plus reading notes and reflections for today.")
        }
    }
    // swiftlint:enable line_length
}
