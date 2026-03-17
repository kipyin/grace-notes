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
        let trace = PerformanceTrace.begin("JournalRepository.fetchEntry")
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            PerformanceTrace.end("JournalRepository.fetchEntry.invalidDate", startedAt: trace)
            return nil
        }
        do {
            let descriptor = FetchDescriptor<JournalEntry>(
                sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
            )
            let entry = try context.fetch(descriptor).first {
                $0.entryDate >= dayStart && $0.entryDate < nextDay
            }
            PerformanceTrace.end("JournalRepository.fetchEntry", startedAt: trace)
            return entry
        } catch {
            PerformanceTrace.end("JournalRepository.fetchEntry.failed", startedAt: trace)
            throw error
        }
    }
}
