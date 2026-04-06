import Foundation

/// Visible and accessibility date line for Past journal search day group headers.
enum PastSearchDayCaption {
    /// - Parameters:
    ///   - dateFormattingLocale: Applied to numeric date branches; relative labels use `String(localized:)`.
    static func string(
        day: Date,
        now: Date,
        calendar: Calendar,
        dateFormattingLocale: Locale = .current
    ) -> String {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: now)

        if dayStart == todayStart {
            return String(localized: "shell.tab.today")
        }

        if let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
           dayStart == yesterdayStart {
            return String(localized: "past.search.dateLabel.yesterday")
        }

        let dayYear = calendar.component(.year, from: dayStart)
        let nowYear = calendar.component(.year, from: todayStart)

        if dayYear == nowYear {
            return dayStart.formatted(
                .dateTime
                    .month(.abbreviated)
                    .day()
                    .locale(dateFormattingLocale)
            )
        }

        return dayStart.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .year()
                .locale(dateFormattingLocale)
        )
    }
}
