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

    func summary(from entries: [JournalEntry], now: Date = .now) -> StreakSummary {
        let today = calendar.startOfDay(for: now)
        let basicByDay = buildCompletionByDay(entries: entries) { $0.hasMeaningfulContent }
        let perfectByDay = buildCompletionByDay(entries: entries) { $0.isComplete || $0.completedAt != nil }

        return StreakSummary(
            basicCurrent: currentStreakLength(byDay: basicByDay, today: today),
            perfectCurrent: currentStreakLength(byDay: perfectByDay, today: today),
            basicDoneToday: basicByDay[today] ?? false,
            perfectDoneToday: perfectByDay[today] ?? false
        )
    }

    private func buildCompletionByDay(
        entries: [JournalEntry],
        completion: (JournalEntry) -> Bool
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
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streakLength
    }
}

extension JournalEntry {
    var hasMeaningfulContent: Bool {
        let hasWrittenNotes = !bibleNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasWrittenReflection = !reflections.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !gratitudes.isEmpty || !needs.isEmpty || !people.isEmpty || hasWrittenNotes || hasWrittenReflection
    }
}
