# Swift for Python: types and optionals

This page uses real examples from this repo.

Use this page to get comfortable with Swift’s “be explicit” style.

## Strong types are everywhere

Swift code in this app is explicit about types.

Examples:

- `JournalCompletionLevel` enum  
  File: `../../GraceNotes/GraceNotes/Data/Models/JournalEntry.swift`
- `ReviewInsightSource` enum  
  File: `../../GraceNotes/GraceNotes/Features/Journal/Services/ReviewInsights.swift`
- `ReminderLiveStatus` enum  
  File: `../../GraceNotes/GraceNotes/Services/Reminders/ReminderScheduler.swift`

Why this helps:
- fewer hidden assumptions
- clearer function contracts
- easier refactoring with compiler help

## Optionals (`?`) are explicit “maybe missing”

Python often uses `None` dynamically.

Swift uses optionals in the type itself.

Examples in this repo:

- `var gratitudes: [JournalItem]?` in `JournalEntry`
- `var completedAt: Date?` in `JournalEntry`
- `private(set) var saveErrorMessage: String?` in `JournalViewModel`

Common pattern you will see:

```swift
(entry.gratitudes ?? []).count
```

That means: use empty array when value is `nil`.

Another common pattern:

```swift
if let value = maybeValue {
    // use value
}
```

This is optional unwrapping in a safe block.

## `let` vs `var`

- `let` = immutable after set
- `var` = mutable

In this repo, immutable local values are common in service/repository code.
Mutable state is common in ViewModels and some SwiftUI views.

You can see both in almost every file.

## Value-returning helpers

Many methods return typed values instead of side effects only.

Examples:

- `completionLevel(...) -> JournalCompletionLevel`
- `exportSnapshot() -> JournalExportPayload`

This makes logic easier to test than side-effect-only code.

## Common confusion

- “Why can’t I just treat optional as normal value?”  
  Swift forces explicit handling so nil bugs are caught early.

- “Why so many enums?”  
  Enums encode real app states (startup phase, reminder state, completion level).

- “Why not dynamic typing like Python?”  
  Swift favors compile-time safety and clear contracts.

## If you know Python

Swift forces “maybe None” handling at compile time.

That feels strict at first, but it removes many runtime null bugs.

## Read next

- Next page: [21-swift-for-python-struct-class-protocol.md](./21-swift-for-python-struct-class-protocol.md)
