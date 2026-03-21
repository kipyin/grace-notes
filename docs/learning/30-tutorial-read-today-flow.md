# Tutorial 30: read the Today flow end to end

## Goal

Understand how one Today entry is loaded, edited, and saved.

No code changes in this tutorial.

## What you need first

- This repo checked out
- Basic Swift syntax comfort
- Optional: markdown notes to write what you find

You do **not** need Xcode for this tutorial.

## Steps

1. Open `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`.
   - Find where `JournalScreen` is added to the Today tab.
2. Open `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`.
   - Find the `.task` block.
   - Note where it calls `loadTodayIfNeeded(using:)`.
3. Open `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`.
   - Read `loadTodayIfNeeded(using:)`.
   - Read `loadEntry(for:using:)`.
   - Read `persistChanges()`.
4. Open `../../GraceNotes/GraceNotes/Data/JournalRepository.swift`.
   - Read `fetchEntry(for:context:)`.
   - Read `fetchEntry(dayStart:context:)`.
5. Return to `JournalViewModel+ChipEditing.swift`.
   - Read one add method (for example `addGratitude`).
   - Follow how it calls `scheduleAutosave()`.

## How to check it worked

Write a short call path in your own words.

You should be able to explain:

- where load starts
- where save happens
- how date-based fetch works
- where chip updates trigger autosave

If you can explain that clearly, this tutorial worked.

## What often goes wrong

- Reading view code only, but skipping ViewModel code.
- Missing that repository fetch uses a day range (`dayStart` to `nextDay`), not exact timestamp equality.
- Missing that chip editing has both immediate UI updates and async summarize steps.

## Optional harder step

Trace the same flow for a **past date** opened from Review:

- start from `ReviewScreen`
- follow `NavigationLink` to `JournalScreen(entryDate:)`
- verify `loadEntry(for:using:)` path for non-today dates
