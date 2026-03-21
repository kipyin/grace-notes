# 16 — Settings, import, export

## What you will learn

You will learn:
- where settings state is stored
- how backup export is created
- how import validation + merge works

This page focuses on user trust features:
- where data is stored
- how backup/restore works
- how settings reflect real runtime state

## Settings entry

File: `../../GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift`

Main sections:

- AI settings row (toggle + cloud connectivity status)
- Reminders controls
- Data & Privacy section

Read this file together with service files below for full flow.

Real snippet:

```swift
@AppStorage("useCloudSummarization") private var useCloudSummarization = false
```

How to read this snippet:
- this setting is persisted in user defaults
- UI toggle and behavior can stay in sync across launches

## Data & Privacy section

File: `../../GraceNotes/GraceNotes/Features/Settings/DataPrivacySettingsSection.swift`

This section shows:

- storage summary
- attention message for iCloud/account state
- optional iCloud sync toggle
- navigation row to import/export screen

It reads runtime persistence state from `persistenceRuntimeSnapshot`.

That is why the copy can show cloud/local/fallback context honestly.

Real snippet:

```swift
@Environment(\.persistenceRuntimeSnapshot) private var persistenceRuntimeSnapshot
```

How to read this snippet:
- screen reads runtime storage state from environment
- UI copy can reflect real startup outcome (including fallback)

## Import/export screen

File: `../../GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift`

Actions:

- export JSON backup file
- import JSON backup file

Uses:

- `JournalDataExportService`
- `JournalDataImportService`

Import path includes confirm step before write.
Export path writes JSON archive then opens share sheet.

Real snippets:

```swift
.fileImporter(
    isPresented: $showImportPicker,
```

```swift
let summary = try await Task.detached(priority: .userInitiated) {
```

How to read these snippets:
- first block opens system file picker
- second block runs import work away from UI thread

## Export service

File: `../../GraceNotes/GraceNotes/Features/Settings/Services/JournalDataExportService.swift`

Behavior:

- fetches all entries sorted by day
- encodes archive payload with schema version
- writes JSON file in temporary directory

Archive includes schema version and full entry payloads.

Real snippet:

```swift
let filename = "five-cubed-journal-export-\(timestampString(from: now)).json"
```

How to read this snippet:
- export file name includes timestamp
- this helps users keep multiple backup files

## Import service

File: `../../GraceNotes/GraceNotes/Features/Settings/Services/JournalDataImportService.swift`

Safety checks:

- max payload size: 100 MB
- max entry count: 10,000
- schema version check
- dedupe by calendar day (last row wins)
- section item cap to `JournalEntry.slotCount`

Write behavior:

- updates existing day rows when present
- inserts new day rows otherwise

This merge style is “replace by day”, not “append duplicate rows per day”.

Real snippets:

```swift
static let maxImportFileSizeBytes = 100 * 1024 * 1024
```

```swift
static let maxImportEntryCount = 10_000
```

```swift
let entries = dedupeByCalendarDayLastWins(archive.entries, calendar: calendar)
```

How to read these snippets:
- first two lines enforce size/count safety
- third line prevents duplicate rows for the same day

## iCloud account status helper

Files:

- `../../GraceNotes/GraceNotes/Features/Settings/Services/ICloudAccountStatusService.swift`
- `../../GraceNotes/GraceNotes/Features/Settings/ICloudAccountStatusModel.swift`
- `../../GraceNotes/GraceNotes/Features/Settings/Services/ICloudAccountStatusTypes.swift`

This is used to choose guidance text and whether toggle should show.

## Common confusion

- “Does iCloud toggle mean immediate migration?”  
  Not immediate. Some messages explicitly say changes apply on next launch.

- “Can import file break app memory?”  
  Service has size and count guards to reduce that risk.

- “Is import overwrite total database?”  
  Import logic merges by calendar day and updates matching day rows.

## If you know Python

Think of import/export services as pure application services.

UI code does file picking and alerts.
Service code does decode/validate/merge rules.

## Read next

[17-reminders.md](./17-reminders.md)

## Quick check

1. Which line shows import runs in detached task?
2. Which line enforces 10,000-entry limit?
3. Which line dedupes by day before write?
