import Foundation
import SwiftData

struct JournalRepository {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func fetchAllEntries(context: ModelContext) throws -> [JournalEntry] {
        let trace = PerformanceTrace.begin("JournalRepository.fetchAllEntries")
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        do {
            let entries = try context.fetch(descriptor)
            PerformanceTrace.end("JournalRepository.fetchAllEntries", startedAt: trace)
            return entries
        } catch {
            PerformanceTrace.end("JournalRepository.fetchAllEntries.failed", startedAt: trace)
            throw error
        }
    }

    func fetchEntry(for date: Date, context: ModelContext) throws -> JournalEntry? {
        let dayStart = calendar.startOfDay(for: date)
        return try fetchEntry(dayStart: dayStart, context: context)
    }

    /// Fetches the journal row for `[dayStart, nextDay)` using the same interval semantics as import and demo seeding.
    func fetchEntry(dayStart: Date, context: ModelContext) throws -> JournalEntry? {
        let trace = PerformanceTrace.begin("JournalRepository.fetchEntry")
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            PerformanceTrace.end("JournalRepository.fetchEntry.invalidDate", startedAt: trace)
            return nil
        }
        do {
            let descriptor = FetchDescriptor<JournalEntry>(
                predicate: #Predicate { entry in
                    entry.entryDate >= dayStart && entry.entryDate < nextDay
                },
                sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
            )
            let entry = try context.fetch(descriptor).first
            PerformanceTrace.end("JournalRepository.fetchEntry", startedAt: trace)
            return entry
        } catch {
            PerformanceTrace.end("JournalRepository.fetchEntry.failed", startedAt: trace)
            throw error
        }
    }
}
