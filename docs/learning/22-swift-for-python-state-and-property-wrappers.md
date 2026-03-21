# Swift for Python: state and property wrappers

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

## `@StateObject`

Owns lifecycle of reference-type observable models in a view.

Example:

- `GraceNotesApp` holds `@StateObject private var startupCoordinator`.
- File: `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`

Use when view owns lifecycle of an observable reference model.

## `@AppStorage`

Reads/writes `UserDefaults` with a property-like API.

Examples:

- onboarding completion flag in `GraceNotesApp`
- settings toggles in `SettingsScreen`

Files:

- `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`
- `../../GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift`

Good for small persisted flags and preferences.

## `@Environment`

Reads values provided by the environment.

Examples:

- `@Environment(\.modelContext)` in `JournalScreen`
- custom runtime snapshot environment in Settings

Files:

- `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`
- `../../GraceNotes/GraceNotes/Application/PersistenceRuntimeSnapshotEnvironment.swift`

Use to read values injected by parent/root context.

## `@Query`

SwiftData-backed query for views.

Example:

- `ReviewScreen` has `@Query(sort: \.entryDate, order: .reverse)`.
- File: `../../GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift`

This is SwiftData-integrated query state for views.

## `@Observable`

Observation macro for state models.

Example:

- `JournalViewModel` is `@Observable`.
- File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`

Used here for view model state change tracking.

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

- Next page: [23-swift-for-python-async-await.md](./23-swift-for-python-async-await.md)
