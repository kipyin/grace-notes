import CoreData
import XCTest
@testable import GraceNotes

@MainActor
final class ICloudSyncActivityModelTests: XCTestCase {
    /// Must stay in sync with `ICloudSyncActivityModel`'s private persistence key.
    private let timestampKey = "ICloudSync.lastRemoteChangeTimestamp"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: timestampKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: timestampKey)
        super.tearDown()
    }

    func test_persistentStoreRemoteChangeNotification_updatesLastRemoteChangeAt() async {
        let model = ICloudSyncActivityModel()
        XCTAssertNil(model.lastRemoteChangeAt)

        model.startMonitoring()
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)

        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if model.lastRemoteChangeAt != nil {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for lastRemoteChangeAt after remote-change notification")
    }
}
