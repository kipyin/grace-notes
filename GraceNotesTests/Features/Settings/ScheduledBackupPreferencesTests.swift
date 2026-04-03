import XCTest
@testable import GraceNotes

final class ScheduledBackupPreferencesTests: XCTestCase {
    private let defaults = UserDefaults.standard

    override func tearDown() {
        defaults.removeObject(forKey: "ScheduledBackup.folderDisplayName")
        defaults.removeObject(forKey: "ScheduledBackup.folderBookmark")
        super.tearDown()
    }

    func test_storeFolderBookmark_persistsDisplayName() throws {
        let folderName = "GraceNotesBackupFolder-\(UUID().uuidString)"
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try ScheduledBackupPreferences.storeFolderBookmark(for: temp)
        XCTAssertEqual(ScheduledBackupPreferences.folderDisplayName, folderName)
    }
}
