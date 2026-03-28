import XCTest

extension XCUIApplication {
    /// Shared UITest launch contract: English locale, `-ui-testing`, optional SwiftData reset for UI tests.
    /// Apply before every `launch()`; a bare `launch()` after `terminate()` can drop arguments on some OS versions.
    /// - Parameter wideReviewRhythm: Matches app `ProcessInfo.graceNotesUITestWideReviewRhythmArgument`.
    func configureGraceNotesUITestLaunch(
        resetUITestStore: Bool = true,
        wideReviewRhythm: Bool = false
    ) {
        var args = [
            "-ui-testing",
            "-grace-notes-uitest-short-autosave",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        if resetUITestStore {
            args.append("-grace-notes-reset-uitest-store")
        }
        if wideReviewRhythm {
            args.append("-grace-notes-uitest-wide-review-rhythm")
        }
        launchArguments = args
    }
}
