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
            let uint64Bytes = num.uint64Value
            if uint64Bytes > UInt64(Int.max) {
                return Int.max
            }
            return Int(uint64Bytes)
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
                // `fetchEntry` picks one canonical row per day; drop any extra rows so import does not
                // leave stale duplicates (see ``JournalRepository/fetchEntry(dayStart:context:)``).
                try coalesceDuplicateJournalRowsForDay(
                    kept: existing,
                    dayStart: dayStart,
                    calendar: calendar,
                    context: context
                )
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
        try coalesceDuplicateRowsForSkippedDays(
            skipDays: skipDays,
            repository: repository,
            context: context,
            calendar: calendar
        )
        return (inserted, updated)
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

    /// ISO8601 decode vs persisted `Date` can differ slightly in sub-second precision; treat as same for merge
    /// detection.
    private static func completedAtEqualForMerge(_ lhsDate: Date?, _ rhsDate: Date?) -> Bool {
        switch (lhsDate, rhsDate) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (lhsDate?, rhsDate?):
            return abs(lhsDate.timeIntervalSince(rhsDate)) < 1.0
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

extension JournalDataImportService {
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
}

private extension JournalDataImportService {
    private func comparisonPayload(for journal: Journal) -> ImportComparisonPayload {
        comparisonPayload(for: exportMapper.makeExportEntry(from: journal))
    }

    /// Merge mode + preferLocal skips applying file fields for conflict days, but we still collapse duplicate
    /// rows so the store stays at most one row per calendar day (canonical row unchanged).
    func coalesceDuplicateRowsForSkippedDays(
        skipDays: Set<Date>,
        repository: JournalRepository,
        context: ModelContext,
        calendar: Calendar
    ) throws {
        for dayStart in skipDays {
            let canonicalDay = calendar.startOfDay(for: dayStart)
            guard let kept = try repository.fetchEntry(dayStart: canonicalDay, context: context) else { continue }
            try coalesceDuplicateJournalRowsForDay(
                kept: kept,
                dayStart: canonicalDay,
                calendar: calendar,
                context: context
            )
        }
    }

    /// When the store violates the one-row-per-day invariant, ``JournalRepository/fetchEntry(dayStart:context:)``
    /// returns the canonical row (`max` by completion rank, chip count, `updatedAt`, then `id`). Before deleting
    /// non-canonical rows, merge any *divergent* payloads into that canonical row so text that only existed on a
    /// duplicate row is not lost. Same-day rows whose payloads already match the canonical row are only deleted.
    func coalesceDuplicateJournalRowsForDay(
        kept: Journal,
        dayStart: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let descriptor = FetchDescriptor<Journal>(
            predicate: #Predicate { entry in
                entry.entryDate >= dayStart && entry.entryDate < nextDay
            }
        )
        let candidates = try context.fetch(descriptor)
        guard candidates.count > 1 else { return }

        let others = candidates.filter { $0.id != kept.id }
        if hasDistinctMergePayloads(canonical: kept, others: others) {
            mergeDuplicateRowsIntoCanonical(kept: kept, others: others, dayStart: dayStart, calendar: calendar)
        }
        for journal in others {
            context.delete(journal)
        }
    }

    func hasDistinctMergePayloads(canonical: Journal, others: [Journal]) -> Bool {
        let canonicalPayload = comparisonPayload(for: canonical)
        return others.contains { comparisonPayload(for: $0) != canonicalPayload }
    }

    /// Merges `others` into `kept` in `updatedAt` order (oldest first). Slots: append unique non-empty texts not yet
    /// present, up to ``Journal/slotCount`` per section. Notes: keep canonical text; append the other’s normalized
    /// text when both differ. Timestamps: earliest `createdAt`, latest `updatedAt`, latest non-nil `completedAt`.
    func mergeDuplicateRowsIntoCanonical(
        kept: Journal,
        others: [Journal],
        dayStart: Date,
        calendar: Calendar
    ) {
        let sortedOthers = others.sorted { $0.updatedAt < $1.updatedAt }
        for other in sortedOthers {
            mergeSlotArrays(into: &kept.gratitudes, from: other.gratitudes)
            mergeSlotArrays(into: &kept.needs, from: other.needs)
            mergeSlotArrays(into: &kept.people, from: other.people)
            mergeNoteField(into: &kept.readingNotes, from: other.readingNotes)
            mergeNoteField(into: &kept.reflections, from: other.reflections)
            if let otherCompleted = other.completedAt {
                if kept.completedAt == nil || otherCompleted > kept.completedAt! {
                    kept.completedAt = otherCompleted
                }
            }
            if other.createdAt < kept.createdAt {
                kept.createdAt = other.createdAt
            }
            if other.updatedAt > kept.updatedAt {
                kept.updatedAt = other.updatedAt
            }
        }
        kept.entryDate = dayStart
    }

    func mergeSlotArrays(into existing: inout [Entry]?, from other: [Entry]?) {
        var current = existing ?? []
        var seenTexts = Set(current.map { clampString($0.fullText.trimmingCharacters(in: .whitespacesAndNewlines)) })
        for item in other ?? [] {
            guard current.count < Journal.slotCount else { break }
            let trimmed = item.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let capped = clampString(trimmed)
            if seenTexts.contains(capped) { continue }
            seenTexts.insert(capped)
            current.append(Entry(fullText: capped, id: item.id))
        }
        existing = current
    }

    func mergeNoteField(into dest: inout String, from other: String) {
        let normalizedDest = normalizeNoteField(dest)
        let normalizedOther = normalizeNoteField(other)
        if normalizedOther.isEmpty { return }
        if normalizedDest.isEmpty {
            dest = normalizedOther
            return
        }
        if normalizedDest == normalizedOther { return }
        let existingParas = Set(
            normalizedDest.split(separator: "\n\n", omittingEmptySubsequences: false).map(String.init)
        )
        let newParas = normalizedOther
            .split(separator: "\n\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.isEmpty && !existingParas.contains($0) }
        guard !newParas.isEmpty else { return }
        dest = clampString(normalizedDest + "\n\n" + newParas.joined(separator: "\n\n"))
    }
}
