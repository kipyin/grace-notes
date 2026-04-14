import Foundation
import SwiftData

enum JournalDataImportError: Error, Equatable {
    case invalidGraceNotesExport
    case unsupportedSchemaVersion(Int)
    case fileTooLarge
    case tooManyEntries
    case mergeConflicts(unresolvedDays: [Date])
}

enum JournalImportMode: Equatable {
    /// Keeps on-device-only days; overlaps with the file either match or become conflicts.
    case merge
    /// Deletes any on-device days that are not in the file, then applies the file.
    case replace
}

enum JournalImportMergeConflictResolution: Equatable {
    case preferImported
    case preferLocal
}

/// Summary of a completed import. `processedDayCount` is unique calendar days after deduplication.
struct JournalDataImportSummary: Equatable {
    let processedDayCount: Int
    let insertedCount: Int
    let updatedCount: Int
}

/// Item counts per section after import sanitization (for tests).
struct JournalDataImportSanitizedLengths: Equatable {
    let gratitudes: Int
    let needs: Int
    let people: Int
}

struct JournalDataImportService {
    /// Caps memory use and import work for malicious or corrupted backups.
    static let maxImportFileSizeBytes = 100 * 1024 * 1024
    static let maxImportEntryCount = 10_000

    private let maxStringFieldLength = 50_000
    private let exportMapper = JournalDataExportService()

    /// Shared with the file picker path so limits stay aligned. Used by tests without allocating huge `Data`.
    internal static func checkImportPayloadByteCount(_ byteCount: Int) throws {
        guard byteCount <= maxImportFileSizeBytes else {
            throw JournalDataImportError.fileTooLarge
        }
    }

    /// Best-effort size before `Data(contentsOf:)`; nil if the platform does not expose a file length.
    static func resolvedFileByteCount(at url: URL) -> Int? {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return size
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let num = attrs[.size] as? NSNumber {
            // Use 64-bit magnitude: `intValue` truncates past 32-bit signed range and can mis-report huge files.
            let v = num.uint64Value
            if v > UInt64(Int.max) {
                return Int.max
            }
            return Int(v)
        }
        return nil
    }

    func importData(
        _ data: Data,
        context: ModelContext,
        calendar: Calendar = .current,
        mode: JournalImportMode = .merge,
        mergeConflictResolution: JournalImportMergeConflictResolution? = nil
    ) throws -> JournalDataImportSummary {
        try Self.checkImportPayloadByteCount(data.count)
        let archive = try decodeArchive(data)
        let entries = dedupeByCalendarDayLastWins(archive.entries, calendar: calendar)
        let repository = JournalRepository(calendar: calendar)

        let conflictDays = try mergeConflictDayStarts(entries: entries, context: context, calendar: calendar)
        if mode == .merge, !conflictDays.isEmpty, mergeConflictResolution == nil {
            throw JournalDataImportError.mergeConflicts(unresolvedDays: conflictDays)
        }

        let skipDays: Set<Date> =
            if mode == .merge && mergeConflictResolution == .preferLocal {
                Set(conflictDays)
            } else {
                []
            }

        if mode == .replace {
            let fileDays = Set(entries.map { calendar.startOfDay(for: $0.entryDate) })
            let locals = try repository.fetchAllEntries(context: context)
            for journal in locals {
                let day = calendar.startOfDay(for: journal.entryDate)
                if !fileDays.contains(day) {
                    context.delete(journal)
                }
            }
        }

        let counts = try applyImportEntries(
            entries,
            skipDays: skipDays,
            repository: repository,
            context: context,
            calendar: calendar
        )

        try context.save()
        let processed = entries.filter { !skipDays.contains(calendar.startOfDay(for: $0.entryDate)) }.count
        return JournalDataImportSummary(
            processedDayCount: processed,
            insertedCount: counts.inserted,
            updatedCount: counts.updated
        )
    }

    private func applyImportEntries(
        _ entries: [JournalDataExportEntry],
        skipDays: Set<Date>,
        repository: JournalRepository,
        context: ModelContext,
        calendar: Calendar
    ) throws -> (inserted: Int, updated: Int) {
        var inserted = 0
        var updated = 0
        for export in entries {
            let dayStart = calendar.startOfDay(for: export.entryDate)
            if skipDays.contains(dayStart) {
                continue
            }
            let sanitized = sanitize(export)

            if let existing = try repository.fetchEntry(dayStart: dayStart, context: context) {
                existing.entryDate = dayStart
                existing.gratitudes = sanitized.gratitudes
                existing.needs = sanitized.needs
                existing.people = sanitized.people
                existing.readingNotes = sanitized.readingNotes
                existing.reflections = sanitized.reflections
                existing.createdAt = sanitized.createdAt
                existing.updatedAt = sanitized.updatedAt
                existing.completedAt = sanitized.completedAt
                updated += 1
            } else {
                context.insert(
                    Journal(
                        id: sanitized.id,
                        entryDate: dayStart,
                        gratitudes: sanitized.gratitudes,
                        needs: sanitized.needs,
                        people: sanitized.people,
                        readingNotes: sanitized.readingNotes,
                        reflections: sanitized.reflections,
                        createdAt: sanitized.createdAt,
                        updatedAt: sanitized.updatedAt,
                        completedAt: sanitized.completedAt
                    )
                )
                inserted += 1
            }
        }
        return (inserted, updated)
    }

    /// Unique calendar day starts (start-of-day) where merge mode would need a conflict decision.
    func mergeConflictDayStarts(
        entries: [JournalDataExportEntry],
        context: ModelContext,
        calendar: Calendar
    ) throws -> [Date] {
        let repository = JournalRepository(calendar: calendar)
        var conflicts: Set<Date> = []
        for export in entries {
            let dayStart = calendar.startOfDay(for: export.entryDate)
            guard let existing = try repository.fetchEntry(dayStart: dayStart, context: context) else {
                continue
            }
            let filePayload = comparisonPayload(for: export)
            let diskPayload = comparisonPayload(for: exportMapper.makeExportEntry(from: existing))
            if filePayload != diskPayload {
                conflicts.insert(dayStart)
            }
        }
        return conflicts.sorted()
    }

    /// Exposed for unit tests that avoid creating a `ModelContext`.
    /// SwiftData in-memory can crash on some Simulator runtimes.
    internal func decodeArchive(_ data: Data) throws -> JournalDataExportArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive: JournalDataExportArchive
        do {
            archive = try decoder.decode(JournalDataExportArchive.self, from: data)
        } catch {
            throw JournalDataImportError.invalidGraceNotesExport
        }
        guard JournalDataExportArchive.supportedImportSchemaVersions.contains(archive.schemaVersion) else {
            throw JournalDataImportError.unsupportedSchemaVersion(archive.schemaVersion)
        }
        guard archive.entries.count <= Self.maxImportEntryCount else {
            throw JournalDataImportError.tooManyEntries
        }
        return archive
    }

    /// Deduplicate by calendar day: sorted by `entryDate`, last row wins for that day.
    internal func dedupeByCalendarDayLastWins(
        _ entries: [JournalDataExportEntry],
        calendar: Calendar
    ) -> [JournalDataExportEntry] {
        let sorted = entries.sorted { $0.entryDate < $1.entryDate }
        var byDayStart: [Date: JournalDataExportEntry] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.entryDate)
            byDayStart[day] = entry
        }
        return byDayStart.keys.sorted().compactMap { byDayStart[$0] }
    }

    /// For unit tests without a live SwiftData stack.
    internal func sanitizedSectionLengths(for export: JournalDataExportEntry) -> JournalDataImportSanitizedLengths {
        let sanitized = sanitize(export)
        return JournalDataImportSanitizedLengths(
            gratitudes: sanitized.gratitudes.count,
            needs: sanitized.needs.count,
            people: sanitized.people.count
        )
    }

    private func comparisonPayload(for export: JournalDataExportEntry) -> ImportComparisonPayload {
        let sanitized = sanitize(export)
        return ImportComparisonPayload(
            gratitudeTexts: sanitized.gratitudes.map(\.fullText),
            needTexts: sanitized.needs.map(\.fullText),
            peopleTexts: sanitized.people.map(\.fullText),
            readingNotes: sanitized.readingNotes,
            reflections: sanitized.reflections,
            completedAt: sanitized.completedAt
        )
    }

    private func sanitize(_ export: JournalDataExportEntry) -> SanitizedExport {
        let gratitudes = mapItems(Array(export.gratitudes.prefix(Journal.slotCount)))
        let needs = mapItems(Array(export.needs.prefix(Journal.slotCount)))
        let people = mapItems(Array(export.people.prefix(Journal.slotCount)))
        return SanitizedExport(
            id: export.id,
            gratitudes: gratitudes,
            needs: needs,
            people: people,
            readingNotes: normalizeNoteField(export.readingNotes),
            reflections: normalizeNoteField(export.reflections),
            createdAt: export.createdAt,
            updatedAt: export.updatedAt,
            completedAt: export.completedAt
        )
    }

    private func mapItems(_ items: [JournalDataExportItem]) -> [Entry] {
        items.compactMap { item in
            let trimmed = item.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let capped = clampString(trimmed)
            return Entry(fullText: capped, id: item.id)
        }
    }

    private func clampString(_ value: String) -> String {
        guard value.count > maxStringFieldLength else { return value }
        return String(value.prefix(maxStringFieldLength))
    }

    private func normalizeNoteField(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clampString(trimmed)
    }

    private struct ImportComparisonPayload: Equatable {
        let gratitudeTexts: [String]
        let needTexts: [String]
        let peopleTexts: [String]
        let readingNotes: String
        let reflections: String
        let completedAt: Date?

        static func == (lhs: ImportComparisonPayload, rhs: ImportComparisonPayload) -> Bool {
            lhs.gratitudeTexts == rhs.gratitudeTexts &&
                lhs.needTexts == rhs.needTexts &&
                lhs.peopleTexts == rhs.peopleTexts &&
                lhs.readingNotes == rhs.readingNotes &&
                lhs.reflections == rhs.reflections &&
                completedAtEqualForMerge(lhs.completedAt, rhs.completedAt)
        }
    }

    /// ISO8601 decode vs persisted `Date` can differ slightly in sub-second precision; treat as same for merge detection.
    private static func completedAtEqualForMerge(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (a?, b?):
            return abs(a.timeIntervalSince(b)) < 1.0
        }
    }

    private struct SanitizedExport {
        let id: UUID
        let gratitudes: [Entry]
        let needs: [Entry]
        let people: [Entry]
        let readingNotes: String
        let reflections: String
        let createdAt: Date
        let updatedAt: Date
        let completedAt: Date?
    }
}
