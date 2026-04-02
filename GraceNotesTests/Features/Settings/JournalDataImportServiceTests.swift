import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
final class JournalDataImportServiceTests: XCTestCase {
    private var calendar: Calendar!
    private var importService: JournalDataImportService!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        importService = JournalDataImportService()
    }

    // MARK: - Pure tests (no SwiftData)

    func test_decode_invalidJSON_throwsInvalidExport() {
        let junk = Data("not json".utf8)

        XCTAssertThrowsError(try importService.decodeArchive(junk)) { error in
            XCTAssertEqual(error as? JournalDataImportError, .invalidGraceNotesExport)
        }
    }

    func test_decode_unsupportedSchema_throws() throws {
        let data = try encodeArchive(
            JournalDataExportArchive(schemaVersion: 3, exportedAt: Date(), entries: [])
        )

        XCTAssertThrowsError(try importService.decodeArchive(data)) { error in
            XCTAssertEqual(error as? JournalDataImportError, .unsupportedSchemaVersion(3))
        }
    }

    func test_decode_acceptsSchema2() throws {
        let data = try encodeArchive(
            JournalDataExportArchive(schemaVersion: 2, exportedAt: Date(), entries: [])
        )

        let archive = try importService.decodeArchive(data)
        XCTAssertEqual(archive.schemaVersion, 2)
        XCTAssertTrue(archive.entries.isEmpty)
    }

    func test_export_makeArchive_usesCurrentSchemaVersion() {
        let exportService = JournalDataExportService()
        let archive = exportService.makeArchive(from: [], exportedAt: Date())
        XCTAssertEqual(archive.schemaVersion, JournalDataExportArchive.currentSchemaVersion)
        XCTAssertEqual(archive.schemaVersion, 2)
    }

    func test_checkImportPayloadByteCount_rejectsOverLimit() {
        let overLimit = JournalDataImportService.maxImportFileSizeBytes + 1
        XCTAssertThrowsError(
            try JournalDataImportService.checkImportPayloadByteCount(overLimit)
        ) { error in
            XCTAssertEqual(error as? JournalDataImportError, .fileTooLarge)
        }
        XCTAssertNoThrow(
            try JournalDataImportService.checkImportPayloadByteCount(JournalDataImportService.maxImportFileSizeBytes)
        )
    }

    func test_decode_tooManyEntries_throws() throws {
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let limit = JournalDataImportService.maxImportEntryCount
        let entries = (0 ..< limit + 1).map { index in
            makeExportEntry(
                id: UUID(),
                entryDate: day,
                gratitudes: [exportItem(fullText: "E\(index)")]
            )
        }
        let data = try encodeArchive(
            JournalDataExportArchive(schemaVersion: 1, exportedAt: day, entries: entries)
        )

        XCTAssertThrowsError(try importService.decodeArchive(data)) { error in
            XCTAssertEqual(error as? JournalDataImportError, .tooManyEntries)
        }
    }

    func test_dedupe_sameCalendarDay_lastRowWins() {
        let noon = Date(timeIntervalSince1970: 1_742_147_200)
        let day = calendar.startOfDay(for: noon)
        let lateSameDay = calendar.date(byAdding: .hour, value: 18, to: day) ?? noon
        let entries = [
            makeExportEntry(
                id: UUID(),
                entryDate: day,
                gratitudes: [exportItem(fullText: "First")]
            ),
            makeExportEntry(
                id: UUID(),
                entryDate: lateSameDay,
                gratitudes: [exportItem(fullText: "Last")]
            )
        ]

        let out = importService.dedupeByCalendarDayLastWins(entries, calendar: calendar)

        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].gratitudes.first?.fullText, "Last")
    }

    func test_sanitize_clampsMoreThanFiveItemsPerSection() {
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let many = (1 ... 7).map { exportItem(fullText: "G\($0)") }
        let export = makeExportEntry(id: UUID(), entryDate: day, gratitudes: many)

        let lengths = importService.sanitizedSectionLengths(for: export)

        XCTAssertEqual(lengths.gratitudes, JournalEntry.slotCount)
        XCTAssertEqual(lengths.needs, 0)
        XCTAssertEqual(lengths.people, 0)
    }

    func test_sanitize_dropsWhitespaceOnlyStripItems() {
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let export = makeExportEntry(
            id: UUID(),
            entryDate: day,
            gratitudes: [
                exportItem(fullText: "  "),
                exportItem(fullText: "\t"),
                exportItem(fullText: "Real")
            ]
        )

        let lengths = importService.sanitizedSectionLengths(for: export)

        XCTAssertEqual(lengths.gratitudes, 1)
    }

    func test_sanitize_legacyChipFieldsIgnored_usesFullTextOnly() throws {
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let export = makeExportEntry(
            id: UUID(),
            entryDate: day,
            gratitudes: [
                JournalDataExportItem(
                    id: UUID(),
                    fullText: "Kept",
                    chipLabel: "Legacy label",
                    isTruncated: true
                )
            ]
        )

        let lengths = importService.sanitizedSectionLengths(for: export)
        XCTAssertEqual(lengths.gratitudes, 1)

        let data = try encodeArchive(
            JournalDataExportArchive(schemaVersion: 1, exportedAt: day, entries: [export])
        )
        let roundTrip = try importService.decodeArchive(data)
        XCTAssertEqual(roundTrip.entries.first?.gratitudes.first?.fullText, "Kept")
        XCTAssertEqual(roundTrip.entries.first?.gratitudes.first?.chipLabel, "Legacy label")
    }

    // MARK: - SwiftData integration

    func test_import_insertsNewEntry_preservingExportId() throws {
        let controller = try PersistenceController.makeInMemoryForTesting()
        let context = ModelContext(controller.container)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let exportId = UUID()
        let data = try encodeArchive(
            JournalDataExportArchive(
                schemaVersion: 1,
                exportedAt: day,
                entries: [
                    makeExportEntry(
                        id: exportId,
                        entryDate: day,
                        gratitudes: [exportItem(fullText: "One")]
                    )
                ]
            )
        )

        let summary = try importService.importData(data, context: context, calendar: calendar)

        XCTAssertEqual(summary.processedDayCount, 1)
        XCTAssertEqual(summary.insertedCount, 1)
        XCTAssertEqual(summary.updatedCount, 0)

        let repo = JournalRepository(calendar: calendar)
        let entry = try XCTUnwrap(try repo.fetchEntry(for: day, context: context))
        XCTAssertEqual(entry.id, exportId)
        XCTAssertEqual((entry.gratitudes ?? []).map(\.fullText), ["One"])
    }

    func test_import_updatesExisting_keepsExistingId() throws {
        let controller = try PersistenceController.makeInMemoryForTesting()
        let context = ModelContext(controller.container)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let existingId = UUID()
        context.insert(
            JournalEntry(
                id: existingId,
                entryDate: day,
                gratitudes: [JournalItem(fullText: "Old")],
                needs: [],
                people: [],
                readingNotes: "",
                reflections: "",
                createdAt: day,
                updatedAt: day
            )
        )
        try context.save()

        let importId = UUID()
        let data = try encodeArchive(
            JournalDataExportArchive(
                schemaVersion: 1,
                exportedAt: day,
                entries: [
                    makeExportEntry(
                        id: importId,
                        entryDate: day,
                        gratitudes: [exportItem(fullText: "New")]
                    )
                ]
            )
        )

        let summary = try importService.importData(data, context: context, calendar: calendar)

        XCTAssertEqual(summary.insertedCount, 0)
        XCTAssertEqual(summary.updatedCount, 1)

        let repo = JournalRepository(calendar: calendar)
        let entry = try XCTUnwrap(try repo.fetchEntry(for: day, context: context))
        XCTAssertEqual(entry.id, existingId)
        XCTAssertEqual((entry.gratitudes ?? []).map(\.fullText), ["New"])
    }

    func test_import_persistsClampedItems() throws {
        let controller = try PersistenceController.makeInMemoryForTesting()
        let context = ModelContext(controller.container)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let manyGratitudes = (1 ... 7).map { exportItem(fullText: "G\($0)") }
        let data = try encodeArchive(
            JournalDataExportArchive(
                schemaVersion: 1,
                exportedAt: day,
                entries: [makeExportEntry(id: UUID(), entryDate: day, gratitudes: manyGratitudes)]
            )
        )

        try importService.importData(data, context: context, calendar: calendar)

        let repo = JournalRepository(calendar: calendar)
        let entry = try XCTUnwrap(try repo.fetchEntry(for: day, context: context))
        XCTAssertEqual((entry.gratitudes ?? []).count, JournalEntry.slotCount)
        XCTAssertEqual((entry.gratitudes ?? []).first?.fullText, "G1")
        XCTAssertEqual((entry.gratitudes ?? []).last?.fullText, "G5")
    }

    private func encodeArchive(_ archive: JournalDataExportArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    private func makeExportEntry(
        id: UUID,
        entryDate: Date,
        gratitudes: [JournalDataExportItem] = [],
        needs: [JournalDataExportItem] = [],
        people: [JournalDataExportItem] = []
    ) -> JournalDataExportEntry {
        JournalDataExportEntry(
            id: id,
            entryDate: entryDate,
            gratitudes: gratitudes,
            needs: needs,
            people: people,
            readingNotes: "",
            reflections: "",
            createdAt: entryDate,
            updatedAt: entryDate,
            completedAt: nil
        )
    }

    private func exportItem(fullText: String) -> JournalDataExportItem {
        JournalDataExportItem(id: UUID(), fullText: fullText)
    }

}
