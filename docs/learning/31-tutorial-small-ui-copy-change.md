# Tutorial 31: make a small UI copy change

## Goal

Change one onboarding sentence and verify it in the app.

This teaches the smallest safe UI edit path.

## What you need first

- macOS + Xcode 15+
- Project opens successfully: `GraceNotes/GraceNotes.xcodeproj`
- You can run the app on a simulator

If you are on Linux, you can still follow the edit steps, but you cannot run the iOS app there.

## Steps

1. Open `../../GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift`.
2. In `pages`, pick one `message` string.
3. Change the text to a short variant.
   - Keep tone calm and clear.
4. Build and run in Xcode.
5. If onboarding does not appear (because the flag is already set), reset app data in simulator and run again.
6. Swipe through onboarding pages and confirm your new text appears.

## How to check it worked

Success means:

- app builds
- onboarding screen shows
- edited sentence appears exactly once where expected
- layout still looks clean (no clipping/truncation)

## What often goes wrong

- Editing the wrong string (title vs message).
- Simulator still has `hasCompletedOnboarding = true`, so onboarding is skipped.
- Copy becomes too long and wraps poorly on smaller devices.

## Optional harder step

Make the same copy update in localization resources and verify both languages in simulator.

Start from:

- `../../GraceNotes/GraceNotes/Localizable.xcstrings`

Keep meaning identical across languages.
