import XCTest
@testable import GraceNotes

final class Orientation051LaunchTests: XCTestCase {
    private var suiteName: String!

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

    func test_applyLaunch_firstInstall_doesNotFlagUpgradeOrientation() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        AppLaunchVersionTracker.applyLaunch(
            defaults: defaults,
            currentMarketingVersionOverride: "0.5.0",
            currentBundleVersionOverride: 7
        )
        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation))
        XCTAssertEqual(defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion), "0.5.0")
        XCTAssertEqual(defaults.integer(forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion), 7)
    }

    func test_applyLaunch_upgradeFrom040_setsPendingAndClearsGuidedKey() {
        assertUpgradeSetsPending(previousMarketing: "0.4.0", previousBundle: nil)
    }

    func test_applyLaunch_upgradeFrom050WithNoStoredBundle_setsPending() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set("0.5.0", forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        AppLaunchVersionTracker.applyLaunch(
            defaults: defaults,
            currentMarketingVersionOverride: "0.5.0",
            currentBundleVersionOverride: 7
        )

        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation))
        XCTAssertNil(defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }

    func test_applyLaunch_upgradeFrom050Build3ToBuild7_setsPending() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set("0.5.0", forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.set(3, forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        AppLaunchVersionTracker.applyLaunch(
            defaults: defaults,
            currentMarketingVersionOverride: "0.5.0",
            currentBundleVersionOverride: 7
        )

        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation))
        XCTAssertNil(defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }

    func test_applyLaunch_secondLaunchAt050Build7_doesNotReflagPending() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set("0.5.0", forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.set(7, forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion)
        defaults.set(false, forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation)

        AppLaunchVersionTracker.applyLaunch(
            defaults: defaults,
            currentMarketingVersionOverride: "0.5.0",
            currentBundleVersionOverride: 7
        )

        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation))
    }

    func test_resolvedGuidedJournal_whenPending051_writesFalseAndBranchPending() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation)

        let resolved = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertFalse(resolved)
        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution))
    }

    func test_resolveBranch_atSoil_clearsFlagWithoutForcingGuidedComplete() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution)
        defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        JournalOnboardingProgress.resolvePending051GuidedJournalBranch(
            todayCompletionLevel: .soil,
            using: defaults
        )

        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution))
        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }

    func test_resolveBranch_atSeed_setsGuidedComplete() {
        assertResolveBranchAtOrAboveSeedSetsGuidedComplete(level: .seed)
    }

    func test_resolveBranch_atRipening_setsGuidedComplete() {
        assertResolveBranchAtOrAboveSeedSetsGuidedComplete(level: .ripening)
    }

    private func assertUpgradeSetsPending(previousMarketing: String, previousBundle: Int?) {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(previousMarketing, forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        if let previousBundle {
            defaults.set(previousBundle, forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion)
        }
        defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        AppLaunchVersionTracker.applyLaunch(
            defaults: defaults,
            currentMarketingVersionOverride: "0.5.0",
            currentBundleVersionOverride: 7
        )

        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation))
        XCTAssertNil(defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
        XCTAssertEqual(defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion), "0.5.0")
        XCTAssertEqual(defaults.integer(forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion), 7)
    }

    private func assertResolveBranchAtOrAboveSeedSetsGuidedComplete(level: JournalCompletionLevel) {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution)

        JournalOnboardingProgress.resolvePending051GuidedJournalBranch(
            todayCompletionLevel: level,
            using: defaults
        )

        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution))
        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }
}
