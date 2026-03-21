# 25 — Swift for Python: SwiftData basics in this repo

## What you will learn

You will learn:
- which objects define store shape
- which objects perform fetch/save work
- how view-level query differs from repository query

This page focuses on what this app actually uses.

Use it as a practical map, not a full SwiftData textbook.

## `@Model` persisted type

`JournalEntry` is declared with `@Model`.

File: `../../GraceNotes/GraceNotes/Data/Models/JournalEntry.swift`

This is the persisted row type for daily entries.

In this app, one logical day maps to one `JournalEntry`.

Real snippet:

```swift
@Model
final class JournalEntry {
```

How to read this snippet:
- this type is persistence-managed
- model lifecycle is not plain class lifecycle

## Model container

`PersistenceController` creates `ModelContainer`.

File: `../../GraceNotes/GraceNotes/Data/Persistence/SwiftData/PersistenceController.swift`

Used for:

- startup disk store
- in-memory test store
- UI test store

Container setup is centralized so startup paths stay consistent.

Real snippets:

```swift
let schema = Schema([JournalEntry.self])
```

```swift
let container = try ModelContainer(for: schema, configurations: configuration)
```

How to read these snippets:
- first line defines model set in store
- second line creates real persistence container

## Model context

`ModelContext` is used for fetch/insert/save.

Examples:

- `JournalViewModel` writes via stored `modelContext`
- import/export screen creates background context from container

`ModelContext` is the object that performs fetch/insert/save actions.

Real snippets:

```swift
@Environment(\.modelContext) private var modelContext
```

```swift
let backgroundContext = ModelContext(container)
```

How to read these snippets:
- first line reads context injected into UI
- second line builds separate context for background work

Files:

- `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`
- `../../GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift`

## Fetching data

`FetchDescriptor<JournalEntry>` is used for queries.

Examples:

- `JournalRepository.fetchAllEntries(...)`
- `JournalRepository.fetchEntry(...)`

Read repository file to see real query predicates and sorting.

Real snippet:

```swift
let descriptor = FetchDescriptor<JournalEntry>(
```

How to read this snippet:
- descriptor defines query shape before fetch executes

File: `../../GraceNotes/GraceNotes/Data/JournalRepository.swift`

## View-level query

`ReviewScreen` uses `@Query` for reactive list data.

File: `../../GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift`

This keeps Review list data reactive as stored entries change.

Real snippet:

```swift
@Query(sort: \JournalEntry.entryDate, order: .reverse) private var entries: [JournalEntry]
```

How to read this snippet:
- this is view-level reactive query binding
- it is convenient for read-heavy screen UI

## One practical pattern to notice

Repository fetches one-day entry by date range:

- `dayStart <= entryDate < nextDay`

That is a stable way to avoid time-of-day mismatch bugs.

## Common confusion

- “Is `@Model` same as plain class?”  
  No. It is persistence-integrated model type.

- “Can views call save directly?”  
  In this repo, save logic is usually coordinated in ViewModel/service layers.

- “Do I need CloudKit to understand this stack?”  
  No. Start with local persistence path, then read cloud preference/fallback notes.

## If you know Python

Think:

- `@Model` ~= ORM model class
- `ModelContext` ~= unit-of-work/session object

But this stack is local-first and integrated into SwiftUI app lifecycle.

## Read next

[30-tutorial-read-today-flow.md](./30-tutorial-read-today-flow.md)

## Quick check

1. Which line creates the SwiftData container?
2. Which line shows view-level reactive query?
3. Why might a background `ModelContext` be used in import/export work?
