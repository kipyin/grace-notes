# Tutorial 32 — Small ViewModel change with tests

## Goal

Add one tiny computed property to `JournalViewModel`, then test it.

This teaches the normal “change + test” loop in this repo.

This is a small but real production-style workflow.

## What you need first

- Understand `JournalViewModel` basics
- macOS + Xcode for running XCTest
- Comfort editing files in:
  - `GraceNotes/GraceNotes/Features/Journal/ViewModels/`
  - `GraceNotesTests/Features/Journal/`

Linux note:
- you can write the code on Linux
- running iOS XCTest still needs macOS + Xcode

---

## Real anchor snippet

```swift
var chipsFilledCount: Int {
    gratitudes.count + needs.count + people.count
}
```

Why this snippet matters:
- it is the exact style used in current ViewModel
- your new property should match this clarity

## Steps (with why)

1. Open `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`.  
   Why: new behavior belongs in ViewModel, not view.

2. Add `hasAnyChipContent` computed property.  
   Example rule: true when any of `gratitudes`, `needs`, `people` is non-empty.  
   Why: tiny scoped behavior change is safer and easier to test.

3. Open `../../GraceNotesTests/Features/Journal/JournalViewModelCompletionAndLimitsTests.swift`.  
   Why: this file already tests nearby computed behavior.

4. Add at least two tests:  
   - all empty -> `false`  
   - one non-empty -> `true`  
   Why: covers core branch behavior.

5. Run only this test file first.  
   Why: fast feedback.

6. Run nearby Journal ViewModel tests after pass.  
   Why: catches regressions in related behavior.

Suggested test sequence:
- run only your new tests first
- then run `JournalViewModelCompletionAndLimitsTests`
- then nearby JournalViewModel test files if needed

## Real snippets to anchor this workflow

From `JournalViewModel` (computed property pattern example):

```swift
var chipsFilledCount: Int {
    gratitudes.count + needs.count + people.count
}
```

From existing test style:

```swift
XCTAssertFalse(viewModel.isChipsFiveCubedComplete)
```

Another assertion style used in repo:

```swift
XCTAssertEqual(viewModel.chipsFilledCount, 14)
```

## Verification checklist

Success means:

- new property compiles
- new tests fail before your change (or would fail without it)
- new tests pass after your change
- existing nearby tests still pass

Helpful evidence to capture:
- test file name
- test names added
- pass/fail result before and after

## What usually breaks (and fixes)

- Adding broad logic in the wrong layer (keep it in ViewModel, not UI file).
- Writing tests that rely on unrelated state.
- Running full suite first (slow); start with the targeted file.

If tests fail unexpectedly:
- check whether test setup creates and loads entry before assertions
- check whether your property uses correct arrays (`gratitudes`, `needs`, `people`)

## Optional harder step

Use the new property in `JournalScreen` for a tiny conditional UI hint, then add one UI test assertion in:

- `../../GraceNotesUITests/JournalUITests.swift`

Keep the UI change very small and easy to verify.

If you do this optional step, add one focused UI assertion only.
