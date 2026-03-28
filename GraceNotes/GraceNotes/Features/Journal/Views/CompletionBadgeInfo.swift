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
            return String(localized: "Empty")
        case .started:
            return String(localized: "Started")
        case .growing:
            return String(localized: "Growing")
        case .balanced:
            return String(localized: "Balanced")
        case .full:
            return String(localized: "Full")
        }
    }

    // swiftlint:disable line_length
    var description: String {
        switch self {
        case .empty:
            return String(localized: "Add one line in each section to move into Sprout.")
        case .started:
            return String(localized: "You have started. Reach three lines in each section to enter Twig.")
        case .growing:
            return String(localized: "At least one section has three lines. Reach three in all sections to enter Leaf.")
        case .balanced:
            return String(localized: "All sections are at three lines. Reach five lines in each section to enter Bloom.")
        case .full:
            return String(localized: "All sections reached five lines. Today's entry is complete.")
        }
    }
    // swiftlint:enable line_length
}
