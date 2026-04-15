import XCTest
@testable import GraceNotes

final class JournalDataExportServiceTests: XCTestCase {
    func test_makeArchive_sortsTiedEntryDateAndCreatedAt_byUUIDComparableOrder() {
        let anchor = Date(timeIntervalSince1970: 1_742_147_200)
        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let journalA = Journal(id: idA, entryDate: anchor, createdAt: anchor, updatedAt: anchor)
        let journalB = Journal(id: idB, entryDate: anchor, createdAt: anchor, updatedAt: anchor)

        let service = JournalDataExportService()
        let archive = service.makeArchive(from: [journalA, journalB], exportedAt: anchor)

        let expectedIds = [idA, idB].sorted(by: <)
        XCTAssertEqual(archive.entries.map(\.id), expectedIds)
    }

    func test_exportFilenameTimestamp_matchesUTCGregorianPattern() {
        let service = JournalDataExportService()
        XCTAssertEqual(service.exportFilenameTimestamp(for: Date(timeIntervalSince1970: 0)), "19700101-000000")
        XCTAssertEqual(service.exportFilenameTimestamp(for: Date(timeIntervalSince1970: 432_000)), "19700106-000000")
        // 1970-01-02 03:04:05 UTC
        XCTAssertEqual(service.exportFilenameTimestamp(for: Date(timeIntervalSince1970: 97_445)), "19700102-030405")
    }
}
