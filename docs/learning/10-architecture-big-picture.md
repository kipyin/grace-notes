# 10 — Architecture big picture

## What you will learn

You will learn the app’s “who does what” map.

After this page, you should know:
- where UI code belongs
- where data query rules belong
- where shared logic belongs

---

## Layer map (real repo)

Source root: `../../GraceNotes/GraceNotes/`

- `Application/` -> app startup + root navigation
- `Features/` -> screens and screen state
- `Data/` -> models + repository + persistence
- `Services/` -> reusable behavior across features
- `DesignSystem/` -> shared look and style

---

## Real snippet set

### Snippet A: root startup owner

File: `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`

```swift
@StateObject private var startupCoordinator: StartupCoordinator
```

### Snippet B: screen state owner

File: `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`

```swift
@State private var viewModel = JournalViewModel()
```

### Snippet C: data boundary in ViewModel

File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`

```swift
@ObservationIgnored private let repository: JournalRepository
```

### Snippet D: query boundary

File: `../../GraceNotes/GraceNotes/Data/JournalRepository.swift`

```swift
func fetchEntry(for date: Date, context: ModelContext) throws -> JournalEntry?
```

---

## How these snippets work together

1. App root owns startup state object.
2. Screen owns UI-facing ViewModel state.
3. ViewModel calls repository for data fetch rules.
4. Repository talks to persistence/query APIs.

This is the practical architecture in this app.

---

## Why this design is used here

If query logic lived in views:
- screen files would grow fast
- behavior would duplicate
- testing would be harder

If everything lived in repository:
- UI state transitions would become messy

Current split is a balanced middle.

---

## Common mistake

Treating all non-UI logic as “service” logic.

In this repo:
- screen behavior state -> ViewModel
- data fetch/write rules -> repository
- cross-feature helper logic -> service

---

## Quick check

1. Which layer owns `JournalRepository`?
2. Which layer owns `JournalScreen`?
3. Which layer owns `StartupCoordinator`?

## Read next

[11-app-startup-flow.md](./11-app-startup-flow.md)
