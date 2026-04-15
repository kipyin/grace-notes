import CoreData
import XCTest
@testable import GraceNotes

@MainActor
final class ICloudSyncActivityModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ICloudSyncActivityModel.persistedTimestampKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ICloudSyncActivityModel.persistedTimestampKey)
        super.tearDown()
    }

    private func waitForLastRemoteChange(
        on model: ICloudSyncActivityModel,
        timeout: TimeInterval = 1,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, model.lastRemoteChangeAt == nil {
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        XCTAssertNotNil(
            model.lastRemoteChangeAt,
            "Timed out waiting for lastRemoteChangeAt after remote-change notification",
            file: file,
            line: line
        )
    }

    func test_persistentStoreRemoteChangeNotification_updatesLastRemoteChangeAt() async {
        let model = ICloudSyncActivityModel()
        XCTAssertNil(model.lastRemoteChangeAt)

        model.startMonitoring()
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)

        await waitForLastRemoteChange(on: model)
    }

    func test_multiplePersistentStoreRemoteChangeNotifications_persistLatestTimestamp() async {
        let model = ICloudSyncActivityModel()
        model.startMonitoring()

        for _ in 0..<8 {
            NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        }

        await waitForLastRemoteChange(on: model)

        let expected = model.lastRemoteChangeAt!.timeIntervalSince1970
        await waitUntilPersistedTimestampEquals(expected)

        XCTAssertEqual(
            UserDefaults.standard.double(forKey: ICloudSyncActivityModel.persistedTimestampKey),
            expected,
            accuracy: 1e-9
        )
    }

    private func waitUntilPersistedTimestampEquals(
        _ expected: TimeInterval,
        timeout: TimeInterval = 1,
        pollIntervalNanoseconds: UInt64 = 1_000_000,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stored = UserDefaults.standard.double(forKey: ICloudSyncActivityModel.persistedTimestampKey)
            if abs(stored - expected) < 1e-9 {
                return
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        XCTFail(
            "Timed out waiting for UserDefaults to match coalesced lastRemoteChangeAt",
            file: file,
            line: line
        )
    }
}
