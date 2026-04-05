import XCTest
@testable import GraceNotes

final class BackupFolderPickerResolutionTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupFolderPickerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        super.tearDown()
    }

    func test_createsDedicatedSubfolderUnderParent() throws {
        let resolved = try BackupFolderPickerResolution.resolvedFolderURL(
            userPicked: tempRoot,
            fileManager: .default
        )
        XCTAssertEqual(resolved.lastPathComponent, BackupFolderPickerResolution.subfolderName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
    }

    func test_doesNotNestWhenUserAlreadySelectedSubfolder() throws {
        let existing = tempRoot.appendingPathComponent(BackupFolderPickerResolution.subfolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        let resolved = try BackupFolderPickerResolution.resolvedFolderURL(
            userPicked: existing,
            fileManager: .default
        )
        XCTAssertEqual(resolved.path, existing.path)
    }
}
