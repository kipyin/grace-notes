import XCTest
@testable import GraceNotes

final class ScheduledBackupPreferencesTests: XCTestCase {
    private let defaults = UserDefaults.standard

    override func tearDown() {
        defaults.removeObject(forKey: "ScheduledBackup.folderDisplayName")
        defaults.removeObject(forKey: "ScheduledBackup.folderBookmark")
        defaults.removeObject(forKey: "ScheduledBackup.intervalRaw")
        defaults.removeObject(forKey: "ScheduledBackup.lastRunAt")
        defaults.removeObject(forKey: "ScheduledBackup.lastFailedAttemptAt")
        defaults.removeObject(forKey: "ScheduledBackup.retentionRaw")
        defaults.removeObject(forKey: "ScheduledBackup.sizeCapRaw")
        super.tearDown()
    }

    func test_isDue_suppressedDuringFailureBackoff() {
        ScheduledBackupPreferences.interval = .daily
        let twoDaysAgo = Date().addingTimeInterval(-86400 * 2)
        ScheduledBackupPreferences.lastRunAt = twoDaysAgo
        ScheduledBackupPreferences.lastFailedAttemptAt = Date()
        XCTAssertFalse(ScheduledBackupPreferences.isDue(now: Date()))

        let pastFailure = Date().addingTimeInterval(-ScheduledBackupPreferences.failureBackoff - 1)
        ScheduledBackupPreferences.lastFailedAttemptAt = pastFailure
        XCTAssertTrue(ScheduledBackupPreferences.isDue(now: Date()))
    }

    func test_backupRetentionAndSizeCap_roundTrip() {
        ScheduledBackupPreferences.backupRetentionPeriod = .days90
        ScheduledBackupPreferences.backupFolderSizeCap = .mb100
        XCTAssertEqual(ScheduledBackupPreferences.backupRetentionPeriod, .days90)
        XCTAssertEqual(ScheduledBackupPreferences.backupFolderSizeCap, .mb100)
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
