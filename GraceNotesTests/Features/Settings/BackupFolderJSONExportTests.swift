import XCTest
@testable import GraceNotes

final class BackupFolderJSONExportTests: XCTestCase {
    func test_copyTempFile_writesExpectedName() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupFolderJSONExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let folder = root.appendingPathComponent("Dest", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let tempRoot = root.appendingPathComponent("Temp", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let tempFile = tempRoot.appendingPathComponent("grace-notes-export-test.json", isDirectory: false)
        try Data("test".utf8).write(to: tempFile)

        let written = try BackupFolderJSONExport.copyTempFile(
            tempFile,
            into: folder,
            destinationFileName: "grace-notes-export-test.json",
            fileManager: .default
        )
        XCTAssertEqual(written, "grace-notes-export-test.json")
        let destination = folder.appendingPathComponent("grace-notes-export-test.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try String(contentsOf: destination), "test")
    }
}
