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
            return String(localized: "Empty means you have not added anything in Gratitudes, Needs, or People in Mind yet.")
        case .started:
            return String(
                localized: "Started means you have begun filling the three sections, and each section still has fewer than three items."
            )
        case .growing:
            return String(
                localized: "Growing means at least one section has three or more items and at least one section still has room to grow."
            )
        case .balanced:
            return String(
                localized: "Balanced means each section has at least three items. Keep going until each section has five for Full."
            )
        case .full:
            return String(
                localized: "Full means all five spots are filled in Gratitudes, Needs, and People in Mind. Reading notes and reflections are separate from this status."
            )
        }
    }
    // swiftlint:enable line_length
}
