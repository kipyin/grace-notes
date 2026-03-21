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

1. [Orientation](./01-orientation.md) ✅ (ready)
2. Repo track (planned pages listed below)
3. Swift track (planned pages listed below)
4. Tutorials (planned pages listed below)

---

## Repo track (how this app is built)

These pages explain app structure and feature call paths.

- [01-orientation.md](./01-orientation.md) — repo layout, opening in Xcode, first reading path
- `10-architecture-big-picture.md` *(planned)*
- `11-app-startup-flow.md` *(planned)*
- `12-data-and-swiftdata.md` *(planned)*
- `13-journal-repository.md` *(planned)*
- `14-journal-ui-and-viewmodel.md` *(planned)*
- `15-summarization.md` *(planned)*
- `16-settings-import-export.md` *(planned)*
- `17-reminders.md` *(planned)*
- `18-onboarding.md` *(planned)*
- `19-tests-and-mocks.md` *(planned)*

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

- `20-swift-for-python-types-and-optionals.md` *(planned)*
- `21-swift-for-python-struct-class-protocol.md` *(planned)*
- `22-swift-for-python-state-and-property-wrappers.md` *(planned)*
- `23-swift-for-python-async-await.md` *(planned)*
- `24-swift-for-python-error-handling.md` *(planned)*
- `25-swift-for-python-swiftdata-basics.md` *(planned)*

---

## Tutorials (small to larger tasks)

Each tutorial will include:
- goal
- what you need first
- steps
- how to check it worked
- common issues
- optional harder step

Planned tutorials:
- `30-tutorial-read-today-flow.md`
- `31-tutorial-small-ui-copy-change.md`
- `32-tutorial-small-viewmodel-change-with-tests.md`

---

## Notes for future updates

- Keep this index in sync with real files in `docs/learning/`.
- If code changes and a page becomes stale, add a short **needs update** note.
- Do not put real secrets in git (for example API keys).
