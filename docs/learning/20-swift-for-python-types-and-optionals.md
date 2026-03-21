# 20 — Swift for Python: types and optionals

## What you will learn

You will learn:
- how Swift type declarations carry behavior meaning
- how optionals are handled in this app
- how to read `let` vs `var` in context

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

Real snippet:

```swift
enum JournalCompletionLevel: String, Equatable {
    case none
    case quickCheckIn
    case standardReflection
    case fullFiveCubed
}
```

How to read this snippet:
- enum gives a closed set of valid states
- raw type `String` helps display/store stable values
- app logic can switch on these cases safely

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

Real snippets from this repo:

```swift
var gratitudes: [JournalItem]?
```

```swift
var completedAt: Date?
```

```swift
gratitudes = entry.gratitudes ?? []
```

How to read these snippets:
- `?` marks “value may be missing”
- `?? []` gives safe default
- code avoids nil crash and keeps logic explicit

## `let` vs `var`

- `let` = immutable after set
- `var` = mutable

In this repo, immutable local values are common in service/repository code.
Mutable state is common in ViewModels and some SwiftUI views.

Real snippet pair:

```swift
private let calendar: Calendar
```

```swift
var entryDate: Date = .now
```

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

[21-swift-for-python-struct-class-protocol.md](./21-swift-for-python-struct-class-protocol.md)

## Quick check

1. What does `var completedAt: Date?` tell you at compile time?
2. Why is `(entry.gratitudes ?? []).count` safer than force unwrapping?
3. Where in this repo is `JournalCompletionLevel` defined?
