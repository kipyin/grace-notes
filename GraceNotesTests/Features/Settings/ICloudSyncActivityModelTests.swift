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
}
