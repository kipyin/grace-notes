import Foundation
import SwiftData

struct JournalDataExportService {
    func exportArchiveFile(
        context: ModelContext,
        now: Date = .now,
        fileManager: FileManager = .default
    ) throws -> URL {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.entryDate, order: .forward)]
        )
        let entries = try context.fetch(descriptor)
        let data = try makeArchiveData(from: entries, exportedAt: now)

        let filename = "five-cubed-journal-export-\(timestampString(from: now)).json"
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func makeArchiveData(from entries: [JournalEntry], exportedAt: Date) throws -> Data {
        let archive = makeArchive(from: entries, exportedAt: exportedAt)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    func makeArchive(from entries: [JournalEntry], exportedAt: Date) -> JournalDataExportArchive {
        let sortedEntries = entries.sorted { $0.entryDate < $1.entryDate }
        return JournalDataExportArchive(
            schemaVersion: 1,
            exportedAt: exportedAt,
            entries: sortedEntries.map(makeExportEntry)
        )
    }

    private func makeExportEntry(from entry: JournalEntry) -> JournalDataExportEntry {
        JournalDataExportEntry(
            id: entry.id,
            entryDate: entry.entryDate,
            gratitudes: entry.gratitudes.map(makeExportItem),
            needs: entry.needs.map(makeExportItem),
            people: entry.people.map(makeExportItem),
            readingNotes: entry.readingNotes,
            reflections: entry.reflections,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            completedAt: entry.completedAt
        )
    }

    private func makeExportItem(from item: JournalItem) -> JournalDataExportItem {
        JournalDataExportItem(
            id: item.id,
            fullText: item.fullText,
            chipLabel: item.chipLabel,
            isTruncated: item.isTruncated
        )
    }

    private func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

struct JournalDataExportArchive: Codable, Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let entries: [JournalDataExportEntry]
}

struct JournalDataExportEntry: Codable, Equatable {
    let id: UUID
    let entryDate: Date
    let gratitudes: [JournalDataExportItem]
    let needs: [JournalDataExportItem]
    let people: [JournalDataExportItem]
    let readingNotes: String
    let reflections: String
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
}

struct JournalDataExportItem: Codable, Equatable {
    let id: UUID
    let fullText: String
    let chipLabel: String?
    let isTruncated: Bool
}
