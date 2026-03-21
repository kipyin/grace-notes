# 12 — Data and SwiftData

## What you will learn

You will learn:
- which types are persisted
- how container setup happens
- how day-based fetch is implemented

This page is about *how* storage works, not just where files are.

## Core data types

### `JournalEntry` (`@Model`)

File: `../../GraceNotes/GraceNotes/Data/Models/JournalEntry.swift`

Important fields:

- `entryDate`
- `gratitudes`, `needs`, `people`
- `readingNotes`
- `reflections`
- `createdAt`, `updatedAt`, `completedAt`

Completion helpers are also here:

- `isComplete`
- `completionLevel`
- `criteriaMet(...)`

Real snippet:

```swift
@Model
final class JournalEntry {
```

How to read this snippet:
- `@Model` means SwiftData manages this type.
- `final class` means reference semantics (needed in this persistence style).

This model is the center of journal persistence.
Most feature flows read or update this type.

### `JournalItem` (`struct`)

File: `../../GraceNotes/GraceNotes/Data/Models/JournalItem.swift`

Represents one chip item:

- `fullText`
- `chipLabel`
- `isTruncated`
- `id`

`displayLabel` chooses `chipLabel` when present, else falls back to `fullText`.

Real snippet:

```swift
struct JournalItem: Codable {
```

How to read this snippet:
- `struct` keeps item value-like and simple.
- `Codable` lets it be encoded/decoded as part of model payloads.

This split lets app keep full user text and a shorter chip label separately.

## Persistence bootstrap

File: `../../GraceNotes/GraceNotes/Data/Persistence/SwiftData/PersistenceController.swift`

`PersistenceController` creates the `ModelContainer`.

It supports:

- normal startup
- in-memory testing
- UI testing store setup

It also tracks whether cloud sync was requested and whether startup used fallback.

That runtime state is carried by:

- `../../GraceNotes/GraceNotes/Data/Persistence/SwiftData/PersistenceRuntimeSnapshot.swift`

That snapshot is injected into SwiftUI environment and used by Settings UI.

Real snippets:

```swift
let schema = Schema([JournalEntry.self])
```

```swift
let container = try ModelContainer(for: schema, configurations: configuration)
```

How to read these snippets:
- first line: define which models are in store
- second line: create the real storage container

## Repository access

Query logic is in:

- `../../GraceNotes/GraceNotes/Data/JournalRepository.swift`

The repository fetches:

- all entries
- one entry for a day (`[dayStart, nextDay)` range)

This day-range query style helps avoid time-of-day mismatch bugs.

Real snippet:

```swift
entry.entryDate >= dayStart && entry.entryDate < nextDay
```

How to read this snippet:
- left side includes start of day
- right side excludes next day
- result: all timestamps in one calendar day map to same day bucket

## Why chip arrays are optional in `JournalEntry`

`JournalEntry` uses optional arrays for chip lists.

The comment in the model explains why: CloudKit/Core Data compatibility during store load.

See comment near:

- `var gratitudes: [JournalItem]?`

Real snippet:

```swift
var gratitudes: [JournalItem]?
```

How to read this snippet:
- `?` means data may be missing at load time
- app code then safely uses `?? []` where needed

## Common confusion

- “Why not store chips as plain `[String]`?”  
  Because app needs `fullText`, `chipLabel`, and truncation state.

- “Why start-of-day normalization?”  
  So one logical day maps to one entry row.

- “Does Linux run this persistence stack?”  
  You can read code on Linux, but app runtime/test execution needs macOS + Xcode.

## If you know Python

`@Model` is not like a plain dataclass.

It is a persisted model type managed by SwiftData.

So reads/writes happen through `ModelContext`, not just in-memory objects.

## Read next

[13-journal-repository.md](./13-journal-repository.md)

## Quick check

1. Which type is the persisted day row?
2. Which snippet shows day-range fetch logic?
3. Why does this app keep both `fullText` and `chipLabel`?
