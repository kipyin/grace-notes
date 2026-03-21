# 11 — App startup flow

## What you will learn

You will learn what runs before the first normal screen appears.

You will also learn where retry/failure behavior is defined.

---

## Real snippet 1: app entry

File: `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`

```swift
@main
struct GraceNotesApp: App {
```

### How this works

- Swift starts here first.
- Root scene chooses loading UI vs ready UI.

---

## Real snippet 2: startup phases

File: `../../GraceNotes/GraceNotes/Application/StartupCoordinator.swift`

```swift
enum Phase {
    case loading
    case reassurance
    case retryableFailure(message: String)
    case ready(PersistenceController)
}
```

### How this works

- startup is modeled as explicit states
- UI can switch cleanly based on state

---

## Real snippet 3: startup work

File: `../../GraceNotes/GraceNotes/Application/StartupCoordinator.swift`

```swift
let controller = try await persistenceFactory()
```

```swift
phase = .ready(controller)
```

### How this works

- coordinator runs async persistence setup
- when setup succeeds, state becomes ready
- app can now show normal content

---

## Real snippet 4: onboarding gate

File: `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`

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

### How this works

- first launch: flag is false -> onboarding appears
- completion callback sets flag true
- later launches skip onboarding

---

## Why this design is used here

Startup can be slow or fail (persistence init, cloud fallback).
Explicit phases avoid “blank screen” confusion.

Onboarding gate at app root keeps first-run logic centralized.

---

## Common mistake

Assuming startup is “just app entry + tab view.”

In this app, startup has:
- asynchronous work
- retry path
- reassurance copy path
- test-mode path

---

## Quick check

1. Which file defines startup phases?
2. Which line switches state to ready?
3. Where is onboarding completion persisted?

## Read next

[12-data-and-swiftdata.md](./12-data-and-swiftdata.md)
