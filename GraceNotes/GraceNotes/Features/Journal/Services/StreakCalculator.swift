import Foundation

struct StreakSummary: Equatable {
    let basicCurrent: Int
    let perfectCurrent: Int
    let basicDoneToday: Bool
    let perfectDoneToday: Bool

    static let empty = StreakSummary(
        basicCurrent: 0,
        perfectCurrent: 0,
        basicDoneToday: false,
        perfectDoneToday: false
    )
}

struct StreakCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func summary(from entries: [Journal], now: Date = .now) -> StreakSummary {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            .map { calendar.startOfDay(for: $0) }
        var basicByDay: [Date: Bool] = [:]
        var perfectByDay: [Date: Bool] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            basicByDay[day] = (basicByDay[day] ?? false) || entry.hasMeaningfulContent
            // Perfect streak uses harvest (all chips / Bloom), not `completedAt`, so completion time cannot inflate it.
            perfectByDay[day] = (perfectByDay[day] ?? false) || entry.hasReachedBloom
        }

        return StreakSummary(
            basicCurrent: currentStreakLength(byDay: basicByDay, today: today, yesterday: yesterday),
            perfectCurrent: currentStreakLength(byDay: perfectByDay, today: today, yesterday: yesterday),
            basicDoneToday: basicByDay[today] ?? false,
            perfectDoneToday: perfectByDay[today] ?? false
        )
    }

    private func currentStreakLength(byDay: [Date: Bool], today: Date, yesterday: Date?) -> Int {
        let startDay: Date
        if byDay[today] == true {
            startDay = today
        } else if let yesterday, byDay[yesterday] == true {
            startDay = yesterday
        } else {
            return 0
        }

        var streakLength = 0
        var cursor = startDay
        while byDay[cursor] == true {
            streakLength += 1
            guard let rawPrevious = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            let previousDay = calendar.startOfDay(for: rawPrevious)
            guard previousDay != cursor else {
                break
            }
            cursor = previousDay
        }
        return streakLength
    }
}
