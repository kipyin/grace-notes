import Foundation
import SwiftData

struct JournalDataExportService {
    func exportArchiveFile(
        context: ModelContext,
        now: Date = .now,
        fileManager: FileManager = .default
    ) throws -> URL {
        let descriptor = FetchDescriptor<Journal>(
            sortBy: [
                SortDescriptor(\.entryDate, order: .forward),
                SortDescriptor(\.createdAt, order: .forward),
                SortDescriptor(\.id, order: .forward)
            ]
        )
        let entries = try context.fetch(descriptor)
        let data = try makeArchiveData(from: entries, exportedAt: now)

        let filename = "grace-notes-export-\(exportFilenameTimestamp(for: now))-\(UUID().uuidString).json"
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func makeArchiveData(from entries: [Journal], exportedAt: Date) throws -> Data {
        let archive = makeArchive(from: entries, exportedAt: exportedAt)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    func makeArchive(from entries: [Journal], exportedAt: Date) -> JournalDataExportArchive {
        let sortedEntries = entries.sorted { lhs, rhs in
            if lhs.entryDate != rhs.entryDate {
                return lhs.entryDate < rhs.entryDate
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            // Ties: `UUID` `<` uses RFC 4122 byte order, not `uuidString` lexicographic order—stable within a build,
            // but can differ from older exports that compared strings.
            return lhs.id < rhs.id
        }
        return JournalDataExportArchive(
            schemaVersion: JournalDataExportArchive.currentSchemaVersion,
            exportedAt: exportedAt,
            entries: sortedEntries.map(makeExportEntry)
        )
    }

    func makeExportEntry(from entry: Journal) -> JournalDataExportEntry {
        JournalDataExportEntry(
            id: entry.id,
            entryDate: entry.entryDate,
            gratitudes: (entry.gratitudes ?? []).map(makeExportItem),
            needs: (entry.needs ?? []).map(makeExportItem),
            people: (entry.people ?? []).map(makeExportItem),
            readingNotes: entry.readingNotes,
            reflections: entry.reflections,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            completedAt: entry.completedAt
        )
    }

    private func makeExportItem(from item: Entry) -> JournalDataExportItem {
        JournalDataExportItem(
            id: item.id,
            fullText: item.fullText
        )
    }

    /// UTC `yyyyMMdd-HHmmss` stamp for export filenames; deterministic and locale-insensitive (`en_US_POSIX`).
    func exportFilenameTimestamp(for date: Date) -> String {
        Self.exportFilenameTimestampFormatter.string(from: date)
    }

    private static let exportFilenameTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT")!
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

struct JournalDataExportArchive: Codable, Equatable {
    /// v2: strip-only items. v1: same import path; items may include legacy `chipLabel` / `entryLabel` / `isTruncated`.
    static let currentSchemaVersion = 2
    static let supportedImportSchemaVersions: Set<Int> = [1, 2]

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

struct JournalDataExportItem: Equatable {
    let id: UUID
    let fullText: String
    /// Legacy pre–strip-only exports; ignored when mapping to `Entry`.
    let entryLabel: String?
    /// Legacy pre–strip-only exports; ignored when mapping to `Entry`.
    let isTruncated: Bool?

    init(id: UUID, fullText: String, entryLabel: String? = nil, isTruncated: Bool? = nil) {
        self.id = id
        self.fullText = fullText
        self.entryLabel = entryLabel
        self.isTruncated = isTruncated
    }
}

extension JournalDataExportItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, fullText, entryLabel, chipLabel, isTruncated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fullText = try container.decode(String.self, forKey: .fullText)
        if let label = try container.decodeIfPresent(String.self, forKey: .entryLabel) {
            entryLabel = label
        } else {
            entryLabel = try container.decodeIfPresent(String.self, forKey: .chipLabel)
        }
        isTruncated = try container.decodeIfPresent(Bool.self, forKey: .isTruncated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullText, forKey: .fullText)
        try container.encodeIfPresent(entryLabel, forKey: .entryLabel)
        try container.encodeIfPresent(isTruncated, forKey: .isTruncated)
    }
}
