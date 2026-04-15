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
            return String(localized: "calendar.weekday.sunday")
        case .mondayStart:
            return String(localized: "calendar.weekday.monday")
        }
    }

    static func resolve(from rawValue: String) -> ReviewWeekBoundaryPreference {
        ReviewWeekBoundaryPreference(rawValue: rawValue) ?? defaultValue
    }

    /// Returns a **Gregorian** calendar for review week boundaries, independent of `base`’s identifier.
    ///
    /// Only `timeZone` and `locale` are read from `base`; other properties (for example
    /// `minimumDaysInFirstWeek`) are not copied. Weekday numbering follows Gregorian convention
    /// (1 = Sunday … 7 = Saturday) for `firstWeekday`, using the same time zone and locale for local
    /// day boundaries and formatting.
    func configuredCalendar(base: Calendar = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = base.timeZone
        calendar.locale = base.locale
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
