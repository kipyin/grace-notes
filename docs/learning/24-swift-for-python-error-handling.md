# Swift for Python: error handling

Swift uses `throw`, `try`, and `do/catch`.

This repo has many practical examples.

Goal of this page:
- spot where errors are turned into user-friendly states
- spot where fallback paths keep feature usable

## Basic pattern in this app

Common shape:

```swift
do {
    // try work
} catch {
    // set user-facing message
}
```

This pattern appears in ViewModels, services, and startup logic.

## Example: journal save failure

File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`

In `persistChanges()`:

- `try context.save()`
- on error sets `saveErrorMessage`

This gives a user-facing message instead of silent failure.

## Example: startup error to retry state

File: `../../GraceNotes/GraceNotes/Application/StartupCoordinator.swift`

`handleStartupFailure(...)` converts failure into:

- `.retryableFailure(message:)`

UI then shows retry action.

This keeps startup resilient instead of crashing or hanging.

## Example: cloud fallback behavior

File: `../../GraceNotes/GraceNotes/Services/Summarization/CloudSummarizer.swift`

Cloud request failure does not crash flow.

It logs and falls back to deterministic summarizer.

So user can keep journaling even when cloud path fails.

## Example: import validation errors

File: `../../GraceNotes/GraceNotes/Features/Settings/Services/JournalDataImportService.swift`

Typed error enum:

- `JournalDataImportError`

Screen maps these to friendly messages:

- `ImportExportSettingsScreen.importFailureMessage(for:)`

This keeps validation strict while still showing clear feedback.

## Common confusion

- “Should every catch show raw error details?”  
  No. User messages should be clear and calm. Internal logs can be more detailed.

- “Is fallback hiding real problems?”  
  Fallback is for continuity. Tests still assert expected fallback behavior.

- “Why use typed error enums?”  
  They make UI message mapping safer and easier to maintain.

## If you know Python

Swift error handling is explicit like typed exceptions.

You must mark throwing functions with `throws` and call them with `try`.

## Read next

- Next page: [25-swift-for-python-swiftdata-basics.md](./25-swift-for-python-swiftdata-basics.md)
