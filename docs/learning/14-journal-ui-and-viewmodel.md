# 14 — Journal UI and ViewModel

## What you will learn

You will learn:
- what belongs in `JournalScreen`
- what belongs in `JournalViewModel`
- how edits become saved data

This is the main feature flow in the app.

If you only study one feature deeply first, pick this one.

## Main screen

File: `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`  
Type: `JournalScreen`

Sections on screen:

- Gratitudes
- Needs
- People in Mind
- Reading Notes
- Reflections

The screen owns:

- local UI state (editing, focus, temporary input strings)
- a `JournalViewModel` for data and rules

`JournalScreen` should mostly coordinate UI behavior, not persistence rules.

Real snippet (initial load trigger):

```swift
viewModel.loadTodayIfNeeded(using: modelContext)
```

How to read this snippet:
- view triggers load
- view does not build fetch query itself

## ViewModel responsibilities

File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`  
Type: `JournalViewModel`

Main jobs:

- load entry for today/date
- create unsaved entry when missing
- autosave edits (debounced)
- compute completion level
- export share payload

The autosave trigger uses Combine debounce (`400ms`) before `persistChanges()`.

Important save path:
- UI edit -> `scheduleAutosave()` -> debounced sink -> `persistChanges()` -> `context.save()`

Real snippets:

```swift
autosaveTrigger
    .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
```

```swift
try context.save()
```

How to read these snippets:
- first block delays rapid save calls
- second line does actual persistence write

## Chip editing behavior

File: `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel+ChipEditing.swift`

Pattern used:

1. Apply immediate chip update with interim label.
2. Run async summarize step.
3. Apply summarize result only if item still matches expected id/text.

This helps avoid stale async updates when user edits quickly.

This is a key design choice in this app:
- responsive UI first
- async refinement second

Real snippets:

```swift
let result = await summarizeForChip(trimmed, section: .gratitude)
```

```swift
gratitudes.append(JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated))
```

```swift
if let idx = gratitudes.firstIndex(where: { $0.id == itemId }),
   gratitudes[idx].fullText == expectedFullText {
```

How to read these snippets:
- async summarize result is computed
- update is applied only if item is still the same item
- this avoids stale async overwrite

UI-side helper functions are in:

- `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreenChipHandling.swift`

Those helpers keep section interaction logic centralized and testable.

## Supporting views

- `SequentialSectionView` for chips + input row
- `ChipView` for each chip
- `EditableTextSection` for notes/reflections
- `DateSectionView` for completion badge and info card

Files:

- `../../GraceNotes/GraceNotes/Features/Journal/Views/SequentialSectionView.swift`
- `../../GraceNotes/GraceNotes/Features/Journal/Views/ChipView.swift`
- `../../GraceNotes/GraceNotes/Features/Journal/Views/EditableTextSection.swift`
- `../../GraceNotes/GraceNotes/Features/Journal/Views/DateSectionView.swift`

## Common confusion

- “Where is chip add logic?”  
  In `JournalViewModel+ChipEditing.swift`, not in `SequentialSectionView`.

- “Where is save called?”  
  In `JournalViewModel.persistChanges()` after debounce.

- “Why can chip label differ from full text?”  
  App stores both so UI can show short chips while preserving full entry text.

## If you know Python

Think of `JournalScreen` as the presentational layer.

Think of `JournalViewModel` as the state + behavior layer.

The split is similar to “UI component + view model/controller” in Python UI stacks.

## Read next

[15-summarization.md](./15-summarization.md)

## Quick check

1. Which file contains debounce save behavior?
2. Why does async chip update verify `id` and `fullText` before apply?
3. Which file should own query predicates: screen or repository?
