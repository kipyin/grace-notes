import XCTest
@testable import GraceNotes

final class ImportExportDetailFormattingTests: XCTestCase {
    func test_detailLooksLikeFileName_trueForExportedJsonNames() {
        let exportName = "grace-notes-export-20260101-120000.json"
        XCTAssertTrue(ImportExportTechnicalDetailFormatting.detailLooksLikeFileName(exportName))
        let scheduledName = "grace-notes-scheduled-20260101-120000.json"
        XCTAssertTrue(ImportExportTechnicalDetailFormatting.detailLooksLikeFileName(scheduledName))
    }

    func test_detailLooksLikeFileName_falseForLocalizedSentences() {
        let english = "Unable to reach the backup folder."
        XCTAssertFalse(ImportExportTechnicalDetailFormatting.detailLooksLikeFileName(english))
        XCTAssertFalse(ImportExportTechnicalDetailFormatting.detailLooksLikeFileName("备份失败"))
    }

    func test_detailLooksLikeFileName_falseWhenWhitespace() {
        XCTAssertFalse(ImportExportTechnicalDetailFormatting.detailLooksLikeFileName("my file.json"))
    }

    func test_detailLooksLikeFileName_falseForEmpty() {
        XCTAssertFalse(ImportExportTechnicalDetailFormatting.detailLooksLikeFileName(""))
        XCTAssertFalse(ImportExportTechnicalDetailFormatting.detailLooksLikeFileName("   "))
    }

    func test_exportHistoryPlainLabel_includesDetailWhenPresent() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: true,
            kind: .manualShare,
            detail: "grace-notes-export-test.json"
        )
        let plain = ImportExportTechnicalDetailFormatting.exportHistoryPlainLabel(for: entry)
        XCTAssertTrue(plain.contains("grace-notes-export-test.json"))
    }

    func test_exportHistoryLineParts_plainLabel_usesSameKindAndStatus() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: false,
            kind: .scheduledFolder,
            detail: nil
        )
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        XCTAssertNil(parts.detail)
        let plain = ImportExportTechnicalDetailFormatting.exportHistoryPlainLabel(for: entry)
        XCTAssertTrue(plain.hasPrefix(parts.kindLabel))
        XCTAssertTrue(plain.contains(parts.statusLabel))
    }
}
