import XCTest
@testable import GraceNotes

final class PersistenceRuntimeSnapshotTests: XCTestCase {
    func test_forInMemory_neverCloudOrFallback() {
        let on = PersistenceRuntimeSnapshot.forInMemory(userRequestedCloudSync: true)
        XCTAssertTrue(on.userRequestedCloudSync)
        XCTAssertFalse(on.storeUsesCloudKit)
        XCTAssertFalse(on.startupUsedCloudKitFallback)

        let off = PersistenceRuntimeSnapshot.forInMemory(userRequestedCloudSync: false)
        XCTAssertFalse(off.userRequestedCloudSync)
        XCTAssertFalse(off.storeUsesCloudKit)
        XCTAssertFalse(off.startupUsedCloudKitFallback)
    }

    func test_forDiskLaunch_cloudSuccess() {
        let s = PersistenceRuntimeSnapshot.forDiskLaunch(
            userRequestedCloudSync: true,
            storeUsesCloudKit: true,
            startupUsedCloudKitFallback: false
        )
        XCTAssertTrue(s.userRequestedCloudSync)
        XCTAssertTrue(s.storeUsesCloudKit)
        XCTAssertFalse(s.startupUsedCloudKitFallback)
    }

    func test_forDiskLaunch_localByChoice() {
        let s = PersistenceRuntimeSnapshot.forDiskLaunch(
            userRequestedCloudSync: false,
            storeUsesCloudKit: false,
            startupUsedCloudKitFallback: false
        )
        XCTAssertFalse(s.userRequestedCloudSync)
        XCTAssertFalse(s.storeUsesCloudKit)
        XCTAssertFalse(s.startupUsedCloudKitFallback)
    }

    func test_forDiskLaunch_silentFallback() {
        let s = PersistenceRuntimeSnapshot.forDiskLaunch(
            userRequestedCloudSync: true,
            storeUsesCloudKit: false,
            startupUsedCloudKitFallback: true
        )
        XCTAssertTrue(s.userRequestedCloudSync)
        XCTAssertFalse(s.storeUsesCloudKit)
        XCTAssertTrue(s.startupUsedCloudKitFallback)
    }

    func test_makeInMemoryForTesting_matchesFactory() throws {
        let controller = try PersistenceController.makeInMemoryForTesting()
        let expected = PersistenceRuntimeSnapshot.forInMemory(userRequestedCloudSync: false)
        XCTAssertEqual(controller.runtimeSnapshot, expected)
    }
}
