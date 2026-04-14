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
        let basicByDay = buildCompletionByDay(entries: entries) { $0.hasMeaningfulContent }
        // "Perfect" = Harvest: all fifteen chips. `completedAt` alone must not inflate this streak.
        let perfectByDay = buildCompletionByDay(entries: entries) { $0.hasReachedBloom }

        return StreakSummary(
            basicCurrent: currentStreakLength(byDay: basicByDay, today: today),
            perfectCurrent: currentStreakLength(byDay: perfectByDay, today: today),
            basicDoneToday: basicByDay[today] ?? false,
            perfectDoneToday: perfectByDay[today] ?? false
        )
    }

    private func buildCompletionByDay(
        entries: [Journal],
        completion: (Journal) -> Bool
    ) -> [Date: Bool] {
        var completionByDay: [Date: Bool] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            completionByDay[day] = (completionByDay[day] ?? false) || completion(entry)
        }
        return completionByDay
    }

    private func currentStreakLength(byDay: [Date: Bool], today: Date) -> Int {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            .map { calendar.startOfDay(for: $0) }
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
