import XCTest
@testable import GraceNotes

/// Launch tracking and legacy `pending051*` migration (version-free post-Seed orientation).
final class Orientation051LaunchTests: XCTestCase {
    private var suiteName: String!

    private let legacyPendingUpgrade = "journalOnboarding.pending051UpgradeOrientation"
    private var legacyPendingBranch: String {
        JournalOnboardingStorageKeys.legacy051GuidedBranchResolution
    }

    override func setUp() {
        super.setUp()
        suiteName = "Orientation051LaunchTests.\(UUID().uuidString)"
    }

    override func tearDown() {
        if let name = suiteName {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        super.tearDown()
    }

    func test_applyLaunch_firstInstall_persistsVersion_only() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        AppLaunchVersionTracker.applyLaunch(
            defaults: defaults,
            currentMarketingVersionOverride: "0.5.0",
            currentBundleVersionOverride: 8
        )
        XCTAssertNil(defaults.object(forKey: legacyPendingUpgrade))
        XCTAssertNil(defaults.object(forKey: legacyPendingBranch))
        XCTAssertEqual(defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion), "0.5.0")
        XCTAssertEqual(defaults.integer(forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion), 8)
    }

    func test_applyLaunch_upgradeFromOlderVersion_doesNotClearGuidedOrSetPending051() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set("0.4.0", forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        AppLaunchVersionTracker.applyLaunch(
            defaults: defaults,
            currentMarketingVersionOverride: "0.5.0",
            currentBundleVersionOverride: 8
        )

        XCTAssertNil(defaults.object(forKey: legacyPendingUpgrade))
        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
        XCTAssertEqual(defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion), "0.5.0")
        XCTAssertEqual(defaults.integer(forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion), 8)
    }

    func test_migrateLegacy_whenUpgradePending_normalizesGuidedAndBranch_thenRemovesUpgradeOnly() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: legacyPendingUpgrade)

        JournalOnboardingProgress.migrateLegacyPostSeedOrientationFlagsIfNeeded(using: defaults)

        XCTAssertNil(defaults.object(forKey: legacyPendingUpgrade))
        XCTAssertTrue(defaults.bool(forKey: legacyPendingBranch))
        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }

    func test_migrateLegacy_preservesBranchFlagUntilResolveRuns() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: legacyPendingBranch)
        defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        JournalOnboardingProgress.migrateLegacyPostSeedOrientationFlagsIfNeeded(using: defaults)

        XCTAssertTrue(defaults.bool(forKey: legacyPendingBranch))
        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }

    func test_resolveBranch_atEmpty_clearsFlagWithoutForcingGuidedComplete() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: legacyPendingBranch)
        defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        JournalOnboardingProgress.resolvePending051GuidedJournalBranch(
            todayCompletionLevel: .empty,
            using: defaults
        )

        XCTAssertNil(defaults.object(forKey: legacyPendingBranch))
        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }

    func test_resolveBranch_atStarted_setsGuidedComplete() {
        assertResolveBranchAtOrAboveStartedSetsGuidedComplete(level: .started)
    }

    func test_resolveBranch_atGrowing_setsGuidedComplete() {
        assertResolveBranchAtOrAboveStartedSetsGuidedComplete(level: .growing)
    }

    func test_resolvedHasCompletedGuidedJournal_afterMigrateFromUpgrade_returnsFalse() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: legacyPendingUpgrade)

        JournalOnboardingProgress.migrateLegacyPostSeedOrientationFlagsIfNeeded(using: defaults)
        let resolved = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertFalse(resolved)
        XCTAssertNil(defaults.object(forKey: legacyPendingUpgrade))
        XCTAssertTrue(defaults.bool(forKey: legacyPendingBranch))
    }

    private func assertResolveBranchAtOrAboveStartedSetsGuidedComplete(level: JournalCompletionLevel) {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: legacyPendingBranch)

        JournalOnboardingProgress.resolvePending051GuidedJournalBranch(
            todayCompletionLevel: level,
            using: defaults
        )

        XCTAssertNil(defaults.object(forKey: legacyPendingBranch))
        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }
}
