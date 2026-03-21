# Grace Notes learning path

This guide is for a Python developer who is new to Swift.

Goal:
- Understand this repo deeply.
- Learn Swift by reading real app code.
- Be ready to fix bugs and add small features.

## Before you start

This app is iOS-only.

You need **macOS + Xcode 15+** to:
- build the app
- run the app in Simulator
- run unit tests and UI tests

On Linux, you can still do useful work:
- read code
- read tests
- run `swiftlint lint`

## Reading order

1. [01 Orientation](./01-orientation.md)
2. Repo track (10–19)
3. Swift track (20–25)
4. Tutorials (30–32)

---

## Repo track (how this app is built)

These pages explain app structure and feature call paths.

- [01-orientation.md](./01-orientation.md) — repo layout, opening in Xcode, first reading path
- [10-architecture-big-picture.md](./10-architecture-big-picture.md)
- [11-app-startup-flow.md](./11-app-startup-flow.md)
- [12-data-and-swiftdata.md](./12-data-and-swiftdata.md)
- [13-journal-repository.md](./13-journal-repository.md)
- [14-journal-ui-and-viewmodel.md](./14-journal-ui-and-viewmodel.md)
- [15-summarization.md](./15-summarization.md)
- [16-settings-import-export.md](./16-settings-import-export.md)
- [17-reminders.md](./17-reminders.md)
- [18-onboarding.md](./18-onboarding.md)
- [19-tests-and-mocks.md](./19-tests-and-mocks.md)

Main code we follow in this track:
- `GraceNotes/GraceNotes/Application/GraceNotesApp.swift` (`GraceNotesApp`)
- `GraceNotes/GraceNotes/Application/StartupCoordinator.swift` (`StartupCoordinator`)
- `GraceNotes/GraceNotes/Data/Persistence/SwiftData/PersistenceController.swift` (`PersistenceController`)
- `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` (`JournalScreen`)
- `GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift` (`JournalViewModel`)
- `GraceNotes/GraceNotes/Data/JournalRepository.swift` (`JournalRepository`)

---

## Swift track (learn Swift from this repo)

Each page teaches one Swift idea with real files from this app.

- [20-swift-for-python-types-and-optionals.md](./20-swift-for-python-types-and-optionals.md)
- [21-swift-for-python-struct-class-protocol.md](./21-swift-for-python-struct-class-protocol.md)
- [22-swift-for-python-state-and-property-wrappers.md](./22-swift-for-python-state-and-property-wrappers.md)
- [23-swift-for-python-async-await.md](./23-swift-for-python-async-await.md)
- [24-swift-for-python-error-handling.md](./24-swift-for-python-error-handling.md)
- [25-swift-for-python-swiftdata-basics.md](./25-swift-for-python-swiftdata-basics.md)

---

## Tutorials (small to larger tasks)

Each tutorial includes:
- goal
- what you need first
- steps
- how to check it worked
- common issues
- optional harder step

Tutorial pages:
- [30-tutorial-read-today-flow.md](./30-tutorial-read-today-flow.md)
- [31-tutorial-small-ui-copy-change.md](./31-tutorial-small-ui-copy-change.md)
- [32-tutorial-small-viewmodel-change-with-tests.md](./32-tutorial-small-viewmodel-change-with-tests.md)

---

## Notes for future updates

- Keep this index in sync with real files in `docs/learning/`.
- If code changes and a page becomes stale, add a short **needs update** note.
- Do not put real secrets in git (for example API keys).
