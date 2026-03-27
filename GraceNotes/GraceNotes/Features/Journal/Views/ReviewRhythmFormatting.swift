import Foundation

/// Shared formatting for the Review reflection rhythm chart (labels, asset catalog image names). Kept small for tests.
enum ReviewRhythmFormatting {
    static func dayLabel(date: Date, currentWeek: Range<Date>, calendar: Calendar) -> String {
        let dayStart = calendar.startOfDay(for: date)
        if currentWeek.contains(dayStart) {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
    }

    /// Asset catalog names (`empty`, `started`, …) for rhythm column pills.
    static func assetName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .empty:
            "empty"
        case .started:
            "started"
        case .growing:
            "growing"
        case .balanced:
            "balanced"
        case .full:
            "full"
        }
    }
}
