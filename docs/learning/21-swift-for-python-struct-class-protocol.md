# 21 — Swift for Python: struct, class, protocol

## What you will learn

You will learn:
- when this repo uses `struct`
- when this repo uses `class`
- why protocols are useful for boundaries and tests

This app uses all three heavily.

Knowing this split will make the repo much easier to read.

## `struct` in this repo

Use `struct` for value-like data.

Examples:

- `JournalItem`  
  File: `../../GraceNotes/GraceNotes/Data/Models/JournalItem.swift`
- `JournalExportPayload`  
  File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`
- `ReviewInsightsProvider`  
  File: `../../GraceNotes/GraceNotes/Features/Journal/Services/ReviewInsightsProvider.swift`

Why this is useful:

- copied by value
- simple data flow
- easier local reasoning

In practice here:
- payload/config/result types are often `struct`
- they move between layers without shared mutable state

Real snippets:

```swift
struct JournalItem: Codable {
```

```swift
struct JournalExportPayload {
```

How to read these snippets:
- both are value-like data carriers
- no UI lifecycle ownership is implied

## `class` in this repo

Use `class` for shared mutable state or framework-required reference types.

Examples:

- `JournalEntry` (`@Model` class for persistence)
- `JournalViewModel` (`@Observable` class for UI state)
- `StartupCoordinator` (`ObservableObject`)

In practice here:
- UI state holders are usually `class`
- persistence model `JournalEntry` is class-based because SwiftData model behavior needs reference semantics

Real snippets:

```swift
@Model
final class JournalEntry {
```

```swift
@Observable
final class JournalViewModel {
```

How to read these snippets:
- class allows shared mutable state updates
- macros/attributes (`@Model`, `@Observable`) signal framework behavior

## Protocols in this repo

Protocols define behavior contracts.

Examples:

- `Summarizer` protocol  
  File: `../../GraceNotes/GraceNotes/Services/Summarization/Summarizer.swift`
- `ReviewInsightsGenerating` protocol  
  File: `../../GraceNotes/GraceNotes/Features/Journal/Services/ReviewInsights.swift`
- `ReminderScheduling` protocol  
  File: `../../GraceNotes/GraceNotes/Services/Reminders/ReminderScheduler.swift`

Implementations can change without changing call sites.

This helps tests inject fakes and spies.

Examples in tests:
- summarizer test doubles in `../../GraceNotesTests/TestDoubles/`

Real snippets:

```swift
protocol Summarizer: Sendable {
```

```swift
protocol ReminderScheduling {
```

How to read these snippets:
- protocol defines capability contract
- implementations can vary without changing caller code

## If you know Python

You can think of protocols like typed interfaces.

They are stricter than Python duck typing, but great for test doubles and clear boundaries.

## Common confusion

- “Should everything be protocol-based?”  
  No. Use protocols when you need a real behavior boundary.

- “Should everything be class-based?”  
  No. Use `struct` by default for simple value data.

- “How do I choose in this repo?”  
  Follow existing patterns in nearby files first.

## Read next

[22-swift-for-python-state-and-property-wrappers.md](./22-swift-for-python-state-and-property-wrappers.md)

## Quick check

1. Which one is a persisted model in this app: `struct JournalItem` or `JournalEntry`?
2. Why is `JournalViewModel` a class instead of struct?
3. Which protocol in this repo is used to abstract summarization behavior?
