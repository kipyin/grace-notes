# 18 — Onboarding flow

## What you will learn

You will learn:
- where onboarding UI is defined
- where onboarding gate logic lives
- how completion state is persisted

This page explains first-run behavior and where to edit it.

## Screen

File: `../../GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift`  
Type: `OnboardingScreen`

Current onboarding is a 3-page flow.

Each page has:

- title
- message

Controls:

- Continue
- Get Started (on last page)
- Skip for now

`selectedPage` tracks the current step in this screen.

Real snippets:

```swift
@State private var selectedPage = 0
```

```swift
Button(String(localized: "Skip for now"), action: onGetStarted)
```

How to read these snippets:
- first line keeps local page index in this screen
- second line provides explicit skip action

## How app decides to show onboarding

File: `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`

`GraceNotesApp` reads:

- `@AppStorage("hasCompletedOnboarding")`

Logic:

- false -> show `OnboardingScreen`
- true -> show main tabs

When onboarding ends, callback sets:

- `hasCompletedOnboarding = true`

This decision is in app root, not in the onboarding screen itself.

Real snippet from app root:

```swift
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
```

```swift
} else if !hasCompletedOnboarding {
    OnboardingScreen {
        hasCompletedOnboarding = true
    }
}
```

How to read these snippets:
- first line reads/writes persisted onboarding flag
- second block gates onboarding at app root
- callback marks onboarding complete

## What onboarding teaches

Current copy focuses on:

- low-pressure start
- gentle section prompts
- value of revisiting in Review tab

The copy aims to reduce pressure and encourage small daily progress.

## Where to change onboarding

Most edits are in `OnboardingScreen.swift`:

- page titles/messages
- button labels
- step count text

If you change onboarding completion behavior, also read:

- `GraceNotesApp.readyContent`

Also check:
- onboarding related localization entries in `Localizable.xcstrings` when changing text.

## Common confusion

- “Why onboarding did not show after edit?”  
  Stored flag may already be true in simulator state.

- “Where is onboarding completion saved?”  
  In `@AppStorage("hasCompletedOnboarding")`.

- “Can I test this on Linux?”  
  You can edit/read code on Linux. Running onboarding UI needs macOS + Xcode.

## If you know Python

`@AppStorage` here acts like a small persisted flag in user defaults.

It is not a database model. It is a simple preference/state flag.

## Read next

[19-tests-and-mocks.md](./19-tests-and-mocks.md)

## Quick check

1. Which line persists onboarding completion state?
2. Which line exposes “Skip for now” action?
3. Which file controls whether onboarding appears at launch?
