# 01 — Orientation

## What you will learn

By the end of this page, you should be able to answer:

1. Where is app entry?
2. Where is startup logic?
3. Where does Today screen load/save data?
4. Which folder should I open first when I debug?

---

## Repo map (first 30 seconds)

At repo root:

- `GraceNotes/` -> app project + app source
- `GraceNotesTests/` -> unit tests
- `GraceNotesUITests/` -> UI tests
- `docs/learning/` -> this guide

Inside `GraceNotes/GraceNotes/`:

- `Application/` -> app start and root navigation
- `Data/` -> models + repository + persistence
- `Features/` -> screen code
- `Services/` -> shared behavior (summarization/reminders)
- `DesignSystem/` -> colors/fonts/spacing

---

## Platform truth

You need macOS + Xcode to run this iOS app.

On Linux, you can still:
- read code
- read tests
- run `swiftlint lint`

---

## First real code chain to read

Follow this order:

1. `Application/GraceNotesApp.swift`
2. `Application/StartupCoordinator.swift`
3. `Data/Persistence/SwiftData/PersistenceController.swift`
4. `Features/Journal/Views/JournalScreen.swift`
5. `Features/Journal/ViewModels/JournalViewModel.swift`
6. `Data/JournalRepository.swift`

This is the minimum path to understand “open app -> load today -> save edits.”

---

## Real snippet 1 (app entry)

File: `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`

```swift
@main
struct GraceNotesApp: App {
```

### How this snippet works

- `@main` tells Swift this is the app entry point.
- `GraceNotesApp` is the root container for startup and tab setup.

### Why this matters in this app

If you do not start here, later files feel disconnected.
This file decides onboarding vs tabs and test vs normal startup path.

---

## Real snippet 2 (startup state machine)

File: `../../GraceNotes/GraceNotes/Application/StartupCoordinator.swift`

```swift
enum Phase {
    case loading
    case reassurance
    case retryableFailure(message: String)
    case ready(PersistenceController)
}
```

### How this snippet works

- Startup is modeled as explicit states.
- UI can render different screens for each state.

### Why this matters in this app

Startup can fail or take time (persistence setup, cloud fallback).
This enum keeps those cases clear instead of hidden booleans.

---

## Real snippet 3 (Today load trigger)

File: `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`

```swift
viewModel.loadTodayIfNeeded(using: modelContext)
```

### How this snippet works

- Screen asks ViewModel to load one entry for today.
- ViewModel uses repository/persistence to fetch or create.

### Why this matters in this app

Load logic is in ViewModel, not in SwiftUI view body.
That keeps UI code simpler and easier to test.

---

## Real snippet 4 (save debounce)

File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`

```swift
.debounce(for: .milliseconds(400), scheduler: RunLoop.main)
```

### How this snippet works

- Many fast edits are grouped.
- Save runs after short quiet period.

### Why this matters in this app

Typing stays smooth.
App avoids saving on every keystroke.

---

## Common mistake

Reading only `JournalScreen.swift` and assuming that is the full behavior.

Most real logic is in:
- `JournalViewModel`
- `JournalRepository`
- persistence setup files

---

## Quick check

1. Which file defines startup phases?
2. Which file contains `loadTodayIfNeeded`?
3. Which file contains date-range fetch (`dayStart` to `nextDay`)?

If you can answer quickly, move to page 10.

## Read next

[10-architecture-big-picture.md](./10-architecture-big-picture.md)
