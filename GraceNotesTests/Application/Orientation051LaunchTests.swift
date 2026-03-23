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
        AppLaunchVersionTracker.applyLaunch(defaults: defaults, currentMarketingVersionOverride: "0.5.1")
        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation))
        XCTAssertEqual(
            defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion),
            "0.5.1"
        )
    }

    func test_applyLaunch_upgradeFrom050_setsPendingAndClearsGuidedKey() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set("0.5.0", forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        AppLaunchVersionTracker.applyLaunch(defaults: defaults, currentMarketingVersionOverride: "0.5.1")

        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation))
        XCTAssertNil(defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
        XCTAssertEqual(
            defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion),
            "0.5.1"
        )
    }

    func test_applyLaunch_secondLaunch051_doesNotReflagPending() {
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set("0.5.1", forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.set(false, forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation)

        AppLaunchVersionTracker.applyLaunch(defaults: defaults, currentMarketingVersionOverride: "0.5.1")

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
        let defaults = UserDefaults(suiteName: suiteName!)!
        defaults.set(true, forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution)

        JournalOnboardingProgress.resolvePending051GuidedJournalBranch(
            todayCompletionLevel: .seed,
            using: defaults
        )

        XCTAssertFalse(defaults.bool(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution))
        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }
}
