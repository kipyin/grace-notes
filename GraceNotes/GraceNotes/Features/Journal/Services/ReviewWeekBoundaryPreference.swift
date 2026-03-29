import Foundation

enum ReviewWeekBoundaryPreference: String, CaseIterable, Equatable, Sendable {
    case sundayStart
    case mondayStart

    static let userDefaultsKey = "reviewWeekBoundaryPreference"
    static let defaultValue: ReviewWeekBoundaryPreference = .sundayStart

    var firstWeekday: Int {
        switch self {
        case .sundayStart:
            return 1
        case .mondayStart:
            return 2
        }
    }

    var localizedLabel: String {
        switch self {
        case .sundayStart:
            return String(localized: "Sunday-Saturday")
        case .mondayStart:
            return String(localized: "Monday-Sunday")
        }
    }

    static func resolve(from rawValue: String) -> ReviewWeekBoundaryPreference {
        ReviewWeekBoundaryPreference(rawValue: rawValue) ?? defaultValue
    }

    func configuredCalendar(base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
