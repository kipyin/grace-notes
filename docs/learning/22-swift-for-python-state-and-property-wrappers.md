# 22 — Swift for Python: state and property wrappers

## What you will learn

You will learn:
- what each wrapper means in this app
- who owns each piece of state
- where state is persisted vs transient

SwiftUI uses property wrappers for state and environment wiring.

This repo has many good real examples.

At first this syntax feels unusual.
Read each wrapper as “where this value comes from.”

## `@State`

Local view-owned mutable state.

Example:

- `JournalScreen` has many `@State` fields for input/editing/focus flow.
- File: `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`

Use when state belongs only to this view instance.

Real snippet:

```swift
@State private var gratitudeInput = ""
```

How to read this snippet:
- state is local to this view instance
- resets when view lifecycle resets

## `@StateObject`

Owns lifecycle of reference-type observable models in a view.

Example:

- `GraceNotesApp` holds `@StateObject private var startupCoordinator`.
- File: `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`

Use when view owns lifecycle of an observable reference model.

Real snippet:

```swift
@StateObject private var startupCoordinator: StartupCoordinator
```

How to read this snippet:
- view owns lifecycle of coordinator object
- object survives body recomputes

## `@AppStorage`

Reads/writes `UserDefaults` with a property-like API.

Examples:

- onboarding completion flag in `GraceNotesApp`
- settings toggles in `SettingsScreen`

Files:

- `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`
- `../../GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift`

Good for small persisted flags and preferences.

Real snippet:

```swift
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
```

How to read this snippet:
- value persists in user defaults
- changing it updates UI logic (onboarding gate)

## `@Environment`

Reads values provided by the environment.

Examples:

- `@Environment(\.modelContext)` in `JournalScreen`
- custom runtime snapshot environment in Settings

Files:

- `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`
- `../../GraceNotes/GraceNotes/Application/PersistenceRuntimeSnapshotEnvironment.swift`

Use to read values injected by parent/root context.

Real snippet:

```swift
@Environment(\.modelContext) private var modelContext
```

How to read this snippet:
- view reads shared dependency from environment
- value is injected by parent/root setup

## `@Query`

SwiftData-backed query for views.

Example:

- `ReviewScreen` has `@Query(sort: \.entryDate, order: .reverse)`.
- File: `../../GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift`

This is SwiftData-integrated query state for views.

Real snippet:

```swift
@Query(sort: \JournalEntry.entryDate, order: .reverse) private var entries: [JournalEntry]
```

How to read this snippet:
- view gets SwiftData-backed list
- list refreshes as data changes

## `@Observable`

Observation macro for state models.

Example:

- `JournalViewModel` is `@Observable`.
- File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`

Used here for view model state change tracking.

Real snippet:

```swift
@Observable
final class JournalViewModel {
```

How to read this snippet:
- model changes are observed by SwiftUI
- used for ViewModel state updates

## If you know Python

Property wrappers are like declarative wiring tags.

They tell SwiftUI where state comes from and who owns it.

## Common confusion

- “Why not normal stored properties?”  
  Because SwiftUI needs lifecycle/ownership info for re-render behavior.

- “Why does wrapper choice matter?”  
  Wrong wrapper can cause lost state or stale state.

- “Do wrappers replace architecture?”  
  No. They support architecture; boundaries still matter.

## Read next

[23-swift-for-python-async-await.md](./23-swift-for-python-async-await.md)

## Quick check

1. Which wrapper in this app persists value across launches?
2. Which wrapper is used for SwiftData list query in `ReviewScreen`?
3. Why is `startupCoordinator` stored as `@StateObject`?
