import XCTest
@testable import GraceNotes

final class BackupFolderLibraryPruneTests: XCTestCase {
    private var root: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupFolderLibraryPruneTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        root = tempRoot
    }

    override func tearDown() {
        if let root = root {
            try? FileManager.default.removeItem(at: root)
        }
        root = nil
        super.tearDown()
    }

    func test_prune_removesFilesOlderThanRetention() throws {
        let root = try XCTUnwrap(root)
        let folder = root.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let old = folder.appendingPathComponent("old.json")
        let recent = folder.appendingPathComponent("recent.json")
        try Data("a".utf8).write(to: old)
        try Data("b".utf8).write(to: recent)

        let tenDaysAgo = Date().addingTimeInterval(-86400 * 10)
        try FileManager.default.setAttributes([.modificationDate: tenDaysAgo], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: recent.path)

        let now = Date()
        try BackupFolderLibrary.prune(
            folderURL: folder,
            now: now,
            retention: .days7,
            maxTotalBytes: nil,
            calendar: Calendar(identifier: .gregorian),
            fileManager: .default
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
    }

    func test_prune_trimsBySizeOldestFirst() throws {
        let root = try XCTUnwrap(root)
        let folder = root.appendingPathComponent("SizeFolder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let first = folder.appendingPathComponent("first.json")
        let second = folder.appendingPathComponent("second.json")
        let payload = Data(repeating: 0, count: 40)
        try payload.write(to: first)
        try payload.write(to: second)

        let olderStamp = Date().addingTimeInterval(-200)
        let newerStamp = Date().addingTimeInterval(-100)
        try FileManager.default.setAttributes([.modificationDate: olderStamp], ofItemAtPath: first.path)
        try FileManager.default.setAttributes([.modificationDate: newerStamp], ofItemAtPath: second.path)

        try BackupFolderLibrary.prune(
            folderURL: folder,
            now: Date(),
            retention: .forever,
            maxTotalBytes: 50,
            calendar: Calendar(identifier: .gregorian),
            fileManager: .default
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func test_prune_ageThenSize() throws {
        let root = try XCTUnwrap(root)
        let folder = root.appendingPathComponent("Both", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let ancient = folder.appendingPathComponent("ancient.json")
        let old = folder.appendingPathComponent("oldish.json")
        let fresh = folder.appendingPathComponent("fresh.json")

        let ancientDate = Date().addingTimeInterval(-86400 * 100)
        let oldDate = Date().addingTimeInterval(-86400 * 10)
        try Data(repeating: 1, count: 30).write(to: ancient)
        try Data(repeating: 2, count: 30).write(to: old)
        try Data(repeating: 3, count: 30).write(to: fresh)
        try FileManager.default.setAttributes([.modificationDate: ancientDate], ofItemAtPath: ancient.path)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fresh.path)

        try BackupFolderLibrary.prune(
            folderURL: folder,
            now: Date(),
            retention: .days30,
            maxTotalBytes: 35,
            calendar: Calendar(identifier: .gregorian),
            fileManager: .default
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: ancient.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
    }
}
