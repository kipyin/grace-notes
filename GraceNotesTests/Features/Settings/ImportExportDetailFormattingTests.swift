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

    func test_exportHistoryLineParts_manualFolder_kindMatchesLocalizationKeyPath() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: true,
            kind: .manualFolder,
            detail: "grace-notes-export-test.json"
        )
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        let plain = ImportExportTechnicalDetailFormatting.exportHistoryPlainLabel(for: entry)
        XCTAssertEqual(
            parts.kindLabel,
            String(localized: "settings.dataPrivacy.importExport.history.kind.manualFolder")
        )
        XCTAssertTrue(plain.contains("grace-notes-export-test.json"))
    }

    func test_exportHistoryLineParts_multilineDetailBecomesSingleLineWithSpaces() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: true,
            kind: .manualShare,
            detail: "first line\nsecond line"
        )
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        XCTAssertEqual(parts.detail, "first line second line")
        let plain = ImportExportTechnicalDetailFormatting.exportHistoryPlainLabel(for: entry)
        XCTAssertTrue(plain.contains("first line second line"))
        XCTAssertFalse(plain.contains("\n"))
    }

    func test_exportHistoryLineParts_whitespaceOnlyDetailIsNil() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: false,
            kind: .manualFolder,
            detail: "   \n  \t  "
        )
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        XCTAssertNil(parts.detail)
        let plain = ImportExportTechnicalDetailFormatting.exportHistoryPlainLabel(for: entry)
        XCTAssertEqual(plain, "\(parts.kindLabel) · \(parts.statusLabel)")
        XCTAssertEqual(plain.components(separatedBy: " · ").count, 2)
    }

    func test_exportHistoryLineParts_trimsSegmentsAroundNewlinesNoDoubleSpaces() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: true,
            kind: .scheduledFolder,
            detail: "foo \n bar"
        )
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        XCTAssertEqual(parts.detail, "foo bar")
        let plain = ImportExportTechnicalDetailFormatting.exportHistoryPlainLabel(for: entry)
        XCTAssertTrue(plain.contains("foo bar"))
        XCTAssertFalse(plain.contains("foo  bar"))
    }

    func test_exportHistoryLineParts_blankLinesBetweenContentCollapseToSingleSpaces() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: true,
            kind: .manualShare,
            detail: "foo\n \nbar"
        )
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        XCTAssertEqual(parts.detail, "foo bar")
    }

    func test_exportHistoryLineParts_leadingAndTrailingNewlinesTrimmed() {
        let entry = BackupExportHistoryEntry(
            id: UUID(),
            finishedAt: Date(),
            success: true,
            kind: .manualShare,
            detail: "\n\ninner\n"
        )
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        XCTAssertEqual(parts.detail, "inner")
    }
}
