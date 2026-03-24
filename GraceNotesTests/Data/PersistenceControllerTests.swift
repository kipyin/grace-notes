import XCTest
@testable import GraceNotes

final class PersistenceControllerTests: XCTestCase {
    func test_cloudSyncEnabled_whenKeyMissing_defaultsToFalse() {
        let defaults = makeIsolatedDefaults()
        defaults.removeObject(forKey: PersistenceController.iCloudSyncEnabledKey)

        let resolvedValue = PersistenceController.cloudSyncEnabled(using: defaults)

        XCTAssertFalse(resolvedValue)
        XCTAssertEqual(
            defaults.object(forKey: PersistenceController.iCloudSyncEnabledKey) as? Bool,
            false
        )
    }

    func test_cloudSyncEnabled_whenKeySetFalse_returnsFalse() {
        let defaults = makeIsolatedDefaults()
        defaults.set(false, forKey: PersistenceController.iCloudSyncEnabledKey)

        let resolvedValue = PersistenceController.cloudSyncEnabled(using: defaults)

        XCTAssertFalse(resolvedValue)
    }

    func test_cloudSyncEnabled_whenKeySetTrue_returnsTrue() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: PersistenceController.iCloudSyncEnabledKey)

        let resolvedValue = PersistenceController.cloudSyncEnabled(using: defaults)

        XCTAssertTrue(resolvedValue)
    }
}

private extension PersistenceControllerTests {
    func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "PersistenceControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
