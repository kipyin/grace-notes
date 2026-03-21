# Tutorial 32: small ViewModel change with tests

## Goal

Add one tiny computed property to `JournalViewModel` and cover it with tests.

This teaches the normal “change + test” loop in this repo.

## What you need first

- Understand `JournalViewModel` basics
- macOS + Xcode for running XCTest
- Comfort editing files in:
  - `GraceNotes/GraceNotes/Features/Journal/ViewModels/`
  - `GraceNotesTests/Features/Journal/`

## Steps

1. Open `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`.
2. Add a small computed property, for example:
   - `hasAnyChipContent` (true when any of gratitudes/needs/people has at least one item).
3. Keep the logic simple and local.
4. Open `../../GraceNotesTests/Features/Journal/JournalViewModelCompletionAndLimitsTests.swift`.
5. Add tests for:
   - all three lists empty -> false
   - at least one list has one item -> true
6. Run the specific test file in Xcode.
7. If tests pass, run related Journal ViewModel test group.

## How to check it worked

Success means:

- new property compiles
- new tests fail before your change (or would fail without it)
- new tests pass after your change
- existing nearby tests still pass

## What often goes wrong

- Adding broad logic in the wrong layer (keep it in ViewModel, not UI file).
- Writing tests that rely on unrelated state.
- Running full suite first (slow); start with the targeted file.

## Optional harder step

Use the new property in `JournalScreen` for a tiny conditional UI hint, then add one UI test assertion in:

- `../../GraceNotesUITests/JournalUITests.swift`

Keep the UI change very small and easy to verify.
