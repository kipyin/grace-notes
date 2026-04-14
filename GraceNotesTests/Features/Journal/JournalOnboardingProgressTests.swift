import XCTest
@testable import GraceNotes

final class JournalOnboardingProgressTests: XCTestCase {
    func test_resolvedHasCompletedGuidedJournal_whenFreshInstall_defaultsToFalse() {
        let defaults = makeIsolatedDefaults()

        let resolvedValue = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertFalse(resolvedValue)
        XCTAssertEqual(
            defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal) as? Bool,
            false
        )
    }

    func test_resolvedHasCompletedGuidedJournal_whenCompletedLegacyOnboarding_setsTrue() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: FirstRunOnboardingStorageKeys.completed)

        let resolvedValue = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertTrue(resolvedValue)
    }

    func test_resolvedHasCompletedGuidedJournal_whenCompletedGuidedJournalIsNSNumberOne_preservesStoredValue() {
        let defaults = makeIsolatedDefaults()
        let one = NSNumber(value: 1)
        defaults.set(one, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        let resolvedValue = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertTrue(resolvedValue)
        let stored = defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        XCTAssertTrue(stored is NSNumber)
        XCTAssertEqual((stored as? NSNumber)?.boolValue, true)
    }

    func test_resolvedHasCompletedGuidedJournal_whenCompletedGuidedJournalIsNSNumberZero_preservesStoredValue() {
        let defaults = makeIsolatedDefaults()
        let zero = NSNumber(value: 0)
        defaults.set(zero, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        let resolvedValue = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertFalse(resolvedValue)
        let stored = defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        XCTAssertTrue(stored is NSNumber)
        XCTAssertEqual((stored as? NSNumber)?.boolValue, false)
    }

    func test_resolvedHasCompletedGuidedJournal_whenCompletedGuidedJournalIsNSNumberNonFinite_interpretsViaBoolValue() {
        let defaults = makeIsolatedDefaults()
        let infinityNumber = NSNumber(value: 1.0 / 0.0)
        defaults.set(infinityNumber, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)

        let resolvedValue = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertTrue(resolvedValue)
        let stored = defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        XCTAssertTrue(stored is NSNumber)
    }

    func test_resolvedHasCompletedGuidedJournal_whenLegacyFirstRunCompletedIsNSNumberOne_migratesWithoutLosingIntent() {
        let defaults = makeIsolatedDefaults()
        defaults.set(NSNumber(value: 1), forKey: FirstRunOnboardingStorageKeys.completed)

        let resolvedValue = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults)

        XCTAssertTrue(resolvedValue)
        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal))
    }

    func test_migrateLegacyPostSeedOrientationFlags_whenBranchResolutionSetAndCompletedGuidedJournalIsNSNumber_doesNotOverwriteWithFalse() {
        let defaults = makeIsolatedDefaults()
        defaults.set(NSNumber(value: 1), forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.legacy051GuidedBranchResolution)

        JournalOnboardingProgress.migrateLegacyPostSeedOrientationFlagsIfNeeded(using: defaults)

        XCTAssertTrue(JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: defaults))
        let stored = defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        XCTAssertTrue(stored is NSNumber)
        XCTAssertEqual((stored as? NSNumber)?.boolValue, true)
    }

    func test_resetAll_clearsGuidedJournalAndSuggestionFlags() {
        let defaults = makeIsolatedDefaults()
        let progress = JournalOnboardingProgress(defaults: defaults)
        progress.hasCompletedGuidedJournal = true
        progress.setDismissed(true, for: .reminders)
        progress.setDismissed(true, for: .iCloudSync)

        JournalOnboardingProgress.resetAll(in: defaults)

        let reloadedProgress = JournalOnboardingProgress(defaults: defaults)
        XCTAssertFalse(reloadedProgress.hasCompletedGuidedJournal)
        XCTAssertFalse(reloadedProgress.hasDismissedSuggestion(.reminders))
        XCTAssertFalse(reloadedProgress.hasDismissedSuggestion(.iCloudSync))
    }

    func test_applyAppTourCompletion_setsSeenGuidedAndDismissesAllMilestoneSuggestions() {
        let defaults = makeIsolatedDefaults()
        let progress = JournalOnboardingProgress(defaults: defaults)

        JournalOnboardingProgress.applyAppTourCompletion(using: defaults)

        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.hasSeenAppTour))
        XCTAssertTrue(progress.hasCompletedGuidedJournal)
        XCTAssertTrue(progress.hasDismissedSuggestion(.reminders))
        XCTAssertTrue(progress.hasDismissedSuggestion(.iCloudSync))
    }

    func test_migrateLegacyAppTourSeenFlag_copiesTrueFromLegacyKeyOnce() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: JournalOnboardingStorageKeys.legacyHasSeenPostSeedJourney)

        JournalOnboardingProgress.migrateLegacyAppTourSeenFlagIfNeeded(using: defaults)

        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.hasSeenAppTour))
    }

    func test_migrateLegacyAppTourSeenFlag_skipsWhenNewKeyAlreadyPresent() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: JournalOnboardingStorageKeys.hasSeenAppTour)
        defaults.set(false, forKey: JournalOnboardingStorageKeys.legacyHasSeenPostSeedJourney)

        JournalOnboardingProgress.migrateLegacyAppTourSeenFlagIfNeeded(using: defaults)

        XCTAssertTrue(defaults.bool(forKey: JournalOnboardingStorageKeys.hasSeenAppTour))
    }
}

private extension JournalOnboardingProgressTests {
    func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "JournalOnboardingProgressTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
