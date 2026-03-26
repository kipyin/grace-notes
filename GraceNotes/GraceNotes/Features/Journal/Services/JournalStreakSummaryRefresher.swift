import Foundation
import SwiftData

enum JournalStreakSummaryRefresher {
    static func loadSummary(
        repository: JournalRepository,
        calculator: StreakCalculator,
        context: ModelContext,
        now: Date
    ) throws -> StreakSummary {
        let entries = try repository.fetchAllEntries(context: context)
        return calculator.summary(from: entries, now: now)
    }
}
