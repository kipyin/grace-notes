# Tutorial 30 — Read the Today flow end to end

## Goal

Build a precise mental model of:
`open app -> load today -> edit -> autosave`.

No code edits in this tutorial.

## Prerequisites

- repo cloned
- basic Swift syntax
- 25–40 minutes

You can do this on Linux (code reading only).

---

## Real anchor snippet

```swift
viewModel.loadTodayIfNeeded(using: modelContext)
```

If you can explain exactly what this line triggers, you understand the core flow.

---

## Steps (with why)

1. Open `../../GraceNotes/GraceNotes/Application/GraceNotesApp.swift`.  
   Why: this shows where Today tab attaches `JournalScreen`.

2. Open `../../GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`.  
   Find `.task` and the anchor snippet.  
   Why: this is the bridge from UI lifecycle to ViewModel loading.

3. Open `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel.swift`.  
   Read:
   - `loadTodayIfNeeded(using:)`
   - `loadEntry(for:using:)`
   - `persistChanges()`
   Why: this is where state + save behavior lives.

4. Open `../../GraceNotes/GraceNotes/Data/JournalRepository.swift`.  
   Read:
   - `fetchEntry(for:context:)`
   - `fetchEntry(dayStart:context:)`
   Why: this is where day-range query rules live.

5. Open `../../GraceNotes/GraceNotes/Features/Journal/ViewModels/JournalViewModel+ChipEditing.swift`.  
   Read one chip add method (for example `addGratitude`).  
   Why: chip edits are a major save trigger.

---

## Snippet checkpoints

From app root:

```swift
NavigationStack {
    JournalScreen()
}
```

From autosave path:

```swift
autosaveTrigger
    .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
```

From repository predicate:

```swift
entry.entryDate >= dayStart && entry.entryDate < nextDay
```

---

## Verification checklist

Write 5 bullets in your own words:

1. Where Today screen is created.
2. Where initial load call happens.
3. Where repository fetch is called.
4. Where save actually happens.
5. Why day-range query is used.

If you can do this without looking back, tutorial succeeded.

---

## What usually breaks (and fixes)

- **Problem:** you read only screen file.  
  **Fix:** always jump into called ViewModel method next.

- **Problem:** you miss date normalization.  
  **Fix:** inspect `startOfDay` + `nextDay` path in repository.

- **Problem:** you miss async chip update guard logic.  
  **Fix:** read one add method and one update method in chip editing extension.

---

## Optional harder step

Trace past-date flow from Review:

- `ReviewScreen` -> `JournalScreen(entryDate:)`
- compare with today default path

Write 3 lines: “same”, “different”, “why difference exists”.
