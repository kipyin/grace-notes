# Completion icon metaphor — Testing notes

## Automated

- `JournalCompletionLevelTests.test_completionStatusSystemImage_matchesCompletionIconDesign` — locks SF Symbol names for each `JournalCompletionLevel` and both `isEmphasized` values per `GraceNotes/docs/agent-log/initiatives/completion-icon-metaphor/design.md`.

## Execution

- **2026-03-23 (macOS):** After `xcodebuild … clean`, focused run succeeded:

  `xcodebuild -project GraceNotes/GraceNotes.xcodeproj -scheme GraceNotes -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -only-testing:GraceNotesTests/JournalCompletionLevelTests/test_completionStatusSystemImage_matchesCompletionIconDesign test`

- **SwiftLint:** `swiftlint lint` on touched Swift sources — 0 violations.

## Next owner

- **QA Reviewer / Test Lead:** Simulator spot-check (completion pill, `PostSeedJourneyPathStrip`, unlock toast) at smallest comfortable Dynamic Type; confirm `leaf` / `tree` legibility at pill size.
