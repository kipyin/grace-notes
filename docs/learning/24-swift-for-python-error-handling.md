# 24 — Swift for Python: error handling

## What you will learn

You will learn:
- where this app surfaces user-friendly errors
- where fallback keeps flow usable
- how typed errors guide UI messaging

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

Real snippet:

```swift
do {
    try context.save()
    saveErrorMessage = nil
} catch {
    saveErrorMessage = String(localized: "Unable to save your journal entry.")
}
```

How to read this snippet:
- success path clears error state
- catch path sets clear user-facing message

## Example: startup error to retry state

File: `../../GraceNotes/GraceNotes/Application/StartupCoordinator.swift`

`handleStartupFailure(...)` converts failure into:

- `.retryableFailure(message:)`

UI then shows retry action.

This keeps startup resilient instead of crashing or hanging.

Real snippet:

```swift
phase = .retryableFailure(message: message)
```

How to read this snippet:
- startup failure is converted to explicit UI state
- app can show retry button instead of breaking silently

## Example: cloud fallback behavior

File: `../../GraceNotes/GraceNotes/Services/Summarization/CloudSummarizer.swift`

Cloud request failure does not crash flow.

It logs and falls back to deterministic summarizer.

So user can keep journaling even when cloud path fails.

Real snippet:

```swift
if let result = try? await fallback.summarize(sentence, section: section) {
    return result
}
```

How to read this snippet:
- cloud error does not stop journaling flow
- fallback path returns usable result

## Example: import validation errors

File: `../../GraceNotes/GraceNotes/Features/Settings/Services/JournalDataImportService.swift`

Typed error enum:

- `JournalDataImportError`

Screen maps these to friendly messages:

- `ImportExportSettingsScreen.importFailureMessage(for:)`

This keeps validation strict while still showing clear feedback.

Real snippet:

```swift
guard archive.entries.count <= Self.maxImportEntryCount else {
    throw JournalDataImportError.tooManyEntries
}
```

How to read this snippet:
- hard limit check runs before write
- typed error makes downstream UI mapping reliable

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

[25-swift-for-python-swiftdata-basics.md](./25-swift-for-python-swiftdata-basics.md)

## Quick check

1. Which snippet maps startup failure into retryable UI state?
2. Which snippet shows fallback behavior after cloud failure?
3. Why is typed import error safer than generic error string matching?
