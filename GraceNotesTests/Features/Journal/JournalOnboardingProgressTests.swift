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
