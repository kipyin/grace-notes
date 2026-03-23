import XCTest
@testable import GraceNotes

final class ICloudSyncPreferenceResolverTests: XCTestCase {
    func test_resolvedCloudSyncEnabled_whenPreferenceStoredFalse_keepsFalse() {
        let defaults = makeIsolatedDefaults()
        defaults.set(false, forKey: PersistenceController.iCloudSyncEnabledKey)

        let resolvedValue = ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: defaults)

        XCTAssertFalse(resolvedValue)
    }

    func test_resolvedCloudSyncEnabled_whenPreferenceStoredTrue_keepsTrue() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: PersistenceController.iCloudSyncEnabledKey)

        let resolvedValue = ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: defaults)

        XCTAssertTrue(resolvedValue)
    }

    func test_resolvedCloudSyncEnabled_whenFreshInstall_defaultsToFalse() {
        let defaults = makeIsolatedDefaults()

        let resolvedValue = ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: defaults)

        XCTAssertFalse(resolvedValue)
        XCTAssertEqual(
            defaults.object(forKey: PersistenceController.iCloudSyncEnabledKey) as? Bool,
            false
        )
    }

    func test_resolvedCloudSyncEnabled_whenCompletedOnboarding_preservesEnabled() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: FirstRunOnboardingStorageKeys.completed)

        let resolvedValue = ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: defaults)

        XCTAssertTrue(resolvedValue)
        XCTAssertEqual(
            defaults.object(forKey: PersistenceController.iCloudSyncEnabledKey) as? Bool,
            true
        )
    }

    func test_resolvedCloudSyncEnabled_whenJournalOnboardingStateExists_preservesEnabled() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        let resolvedValue = ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: defaults)

        XCTAssertTrue(resolvedValue)
    }
}

private extension ICloudSyncPreferenceResolverTests {
    func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "ICloudSyncPreferenceResolverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
