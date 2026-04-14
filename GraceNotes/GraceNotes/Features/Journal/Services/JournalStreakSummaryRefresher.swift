import Foundation
import SwiftData

enum JournalStreakSummaryRefresher {
    /// Computes streak summary from a journal list already loaded from the store (avoids a second full fetch).
    ///
    /// - Parameter entries: Must include every journal row that could affect streak continuity—typically the same
    ///   set as ``JournalRepository/fetchAllEntries(context:)``. Passing a filtered subset (for example only recent
    ///   days) omits older days from the per-day map, so the streak length can be shorter than the user's real streak.
    static func loadSummary(
        calculator: StreakCalculator,
        entries: [Journal],
        now: Date
    ) -> StreakSummary {
        calculator.summary(from: entries, now: now)
    }

    /// Loads all journal rows via ``JournalRepository/fetchAllEntries(context:)`` and computes streak metadata.
    /// Prefer ``loadSummary(calculator:entries:now:)`` when entries are already in memory.
    static func loadSummary(
        repository: JournalRepository,
        calculator: StreakCalculator,
        context: ModelContext,
        now: Date
    ) throws -> StreakSummary {
        let entries = try repository.fetchAllEntries(context: context)
        return loadSummary(calculator: calculator, entries: entries, now: now)
    }
}
