# Import & Export settings polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address the Import & Export audit findings plus product polish: latest export summary on the main screen with full history in a sheet, fix scheduled-backup helper copy layout, show the chosen backup folder name, and remove the duplicate chevron on the backup-folder import row.

**Architecture:** Keep persistence in `UserDefaults` via `BackupExportHistoryStore` and `ScheduledBackupPreferences`. Add a small optional display-name string alongside the folder bookmark (set when the user picks a folder). Refactor `ImportExportSettingsScreen` rows into two label styles—**action row with trailing chevron** (opens picker/share) vs **navigation row with system chevron only** (`NavigationLink` must not also draw `Image(systemName: "chevron.right")`). Use `Section` `footer` for the scheduled-backup explainer instead of a zero-inset `Text` row. Add an `ExportHistorySheet` (or private nested view) listing all history entries.

**Tech Stack:** SwiftUI, SwiftData (unchanged), `Localizable.xcstrings` (EN + zh-Hans), `grace test --kind unit`, `grace ci`.

---

## File map

| File | Responsibility |
|------|----------------|
| `GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupPreferences.swift` | Persist optional **folder display name** when storing bookmark; expose getter; clear when appropriate (define: clear never unless new pick replaces—YAGNI). |
| `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift` | Main list layout: latest export + “see all” sheet; scheduled section footer + folder subtitle row; navigation row without duplicate chevron; accessibility hints. |
| `GraceNotes/GraceNotes/Localizable.xcstrings` | New keys: e.g. export latest summary, “View export history”, empty history, folder label format, a11y hint for disabled backup import. |
| `GraceNotesTests/.../ScheduledBackupPreferencesTests.swift` | **Create** if absent: unit test(s) for display name persistence (use dedicated `UserDefaults` suite id, tearDown cleanup). Optional: keep file colocated with other Settings service tests. |

---

### Task 1: Folder display name persistence

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupPreferences.swift`
- Create: `GraceNotesTests/Features/Settings/ScheduledBackupPreferencesTests.swift` (or nearest existing folder)
- Test: same new test file

- [x] **Step 1: Write failing test**

Add a test that uses `UserDefaults(suiteName: "GraceNotesTests.ScheduledBackup")` **or** `UserDefaults.standard` with unique keys—if the project avoids suites, temporarily swap keys with `tearDown` deleting `ScheduledBackup.intervalRaw`, `ScheduledBackup.folderBookmark`, **`ScheduledBackup.folderDisplayName`** (new).

```swift
import XCTest
@testable import GraceNotes

final class ScheduledBackupPreferencesTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let displayKey = "ScheduledBackup.folderDisplayName"

    override func tearDown() {
        defaults.removeObject(forKey: displayKey)
        defaults.removeObject(forKey: "ScheduledBackup.folderBookmark")
        super.tearDown()
    }

    func test_storeFolderBookmark_persistsDisplayName() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesBackupFolder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try ScheduledBackupPreferences.storeFolderBookmark(for: temp)
        XCTAssertEqual(defaults.string(forKey: displayKey), temp.lastPathComponent)
    }
}
```

Expected: **compile fails** until API stores display name.

- [x] **Step 2: Run test — expect FAIL**

Run: `grace test --kind unit` from repo root (or run `ScheduledBackupPreferencesTests` only in Xcode using `-only-testing GraceNotesTests/ScheduledBackupPreferencesTests` if you need a tight loop).

Expected: FAIL (missing symbol or assertion) until Step 3 lands.

- [x] **Step 3: Implement**

In `ScheduledBackupPreferences`:

- Add private key `"ScheduledBackup.folderDisplayName"`.
- Add `static var folderDisplayName: String?` { get/set on UserDefaults }.
- In `storeFolderBookmark(for:)`, after successful `bookmarkData`, set `folderDisplayName = url.lastPathComponent` (non-empty).

Do **not** clear display name on resolve failure (user can still see last name); optional follow-up if product wants clear on stale bookmark.

- [x] **Step 4: Run test — expect PASS**

Run: `grace test --kind unit`

- [x] **Step 5: Commit**

```bash
git add GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupPreferences.swift GraceNotesTests/Features/Settings/ScheduledBackupPreferencesTests.swift
git commit -m "feat(settings): persist scheduled backup folder display name"
```

---

### Task 2: Navigation row without duplicate chevron

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift` (private extension ~`settingsRow`)

- [ ] **Step 1: Add overload or parameter**

Add:

```swift
func settingsRow(label: String, showTrailingChevron: Bool = true) -> some View {
    HStack(spacing: AppTheme.spacingRegular) {
        Text(label)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextPrimary)
        Spacer(minLength: AppTheme.spacingRegular)
        if showTrailingChevron {
            Image(systemName: "chevron.right")
                .font(AppTheme.outfitSemiboldCaption)
                .foregroundStyle(AppTheme.settingsTextMuted)
        }
    }
    .frame(minHeight: 44)
    .contentShape(Rectangle())
}
```

Replace existing `settingsRow(label:)` implementation with the above (default `true` preserves all current call sites).

- [ ] **Step 2: Use `showTrailingChevron: false` on `NavigationLink` label**

For `NavigationLink { BackupFolderImportFileListView ... } label:`, call:

`settingsRow(label: String(localized: "…"), showTrailingChevron: false)`

- [ ] **Step 3: Build**

Run: `grace ci`  
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git commit -am "fix(settings): single chevron on backup folder NavigationLink"
```

---

### Task 3: Scheduled backup section — folder subtitle + footer layout

**Files:**
- Modify: `ImportExportSettingsScreen.swift`
- Modify: `Localizable.xcstrings` (EN + zh-Hans)

- [ ] **Step 1: Move explainer to `Section` footer**

Replace the standalone `Text(...footer...).listRowInsets(EdgeInsets())` row with:

```swift
Section {
    // picker, choose folder button, optional folder subtitle row
} header: { ... } footer: {
    Text(String(localized: "DataPrivacy.scheduledBackup.footer"))
        .font(AppTheme.warmPaperMeta)
        .foregroundStyle(AppTheme.settingsTextMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

Adjust key copy if footer typography still feels cramped (optional shorter string).

- [ ] **Step 2: Add folder subtitle row (read-only)**

When `ScheduledBackupPreferences.folderBookmarkData != nil` **and** `folderDisplayName` non-nil:

```swift
HStack(alignment: .top, spacing: AppTheme.spacingRegular) {
    Text(String(localized: "DataPrivacy.scheduledBackup.folderLabel"))
        .font(AppTheme.warmPaperMeta)
        .foregroundStyle(AppTheme.settingsTextMuted)
    Text(displayName)
        .font(AppTheme.warmPaperBody)
        .foregroundStyle(AppTheme.settingsTextPrimary)
        .multilineTextAlignment(.trailing)
}
```

Use localized format if preferred: `String(format: String(localized: "DataPrivacy.scheduledBackup.folderValue"), name)`.

Add keys to `Localizable.xcstrings` with zh-Hans parity.

- [ ] **Step 3: Build + spot-check**

Run: `grace ci`

- [ ] **Step 4: Commit**

```bash
git commit -am "fix(settings): scheduled backup footer + folder name row"
```

---

### Task 4: Export history — latest on list, full history in sheet

**Files:**
- Modify: `ImportExportSettingsScreen.swift`
- Modify: `Localizable.xcstrings`

- [ ] **Step 1: State + sheet**

Add:

```swift
@State private var showExportHistorySheet = false
private var exportHistoryEntries: [BackupExportHistoryEntry] {
    BackupExportHistoryStore.load()
}
private var latestExportEntry: BackupExportHistoryEntry? {
    exportHistoryEntries.first
}
```

- [ ] **Step 2: Replace history `Section` with compact block under Export**

When `latestExportEntry != nil`:

- One row: title line = formatted `finishedAt`; subtitle = `historyDetailLabel(for: latest)` **or** shorter “status + kind” only.
- Second row / trailing: `Button` “View export history” opening `showExportHistorySheet = true`.

When **no** history: show nothing extra (YAGNI: no empty placeholder unless product asks).

- [ ] **Step 3: Sheet content**

`.sheet(isPresented: $showExportHistorySheet) { NavigationStack { List { ForEach(exportHistoryEntries) { … same cell as before … } } .navigationTitle(…) .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showExportHistorySheet = false } } } } }`

Reuse a private `ExportHistoryRow(entry:)` view to avoid duplication.

- [ ] **Step 4: Accessibility**

On latest combined block, set a clear `accessibilityLabel` including success/failure (audit).

- [ ] **Step 5: Strings**

Add localized title e.g. `DataPrivacy.importExport.history.sheetTitle` = "Export history"; button `DataPrivacy.importExport.history.viewAll`.

- [ ] **Step 6: Verify**

Run: `grace ci` then `grace test --kind unit`

- [ ] **Step 7: Commit**

```bash
git commit -am "feat(settings): export history sheet with latest on main list"
```

---

### Task 5: Audit follow-ups (accessibility + risk)

**Files:**
- Modify: `ImportExportSettingsScreen.swift`
- Modify: `Localizable.xcstrings`

- [ ] **Disabled backup-folder link hint**  
When `scheduledFolderMissing`, on the `NavigationLink`:

```swift
.accessibilityHint(String(localized: "DataPrivacy.importExport.backupFolder.disabledHint"))
```

- [ ] **Merge conflict + sheet (optional medium)**  
If timeboxed: dismiss import review sheet **before** presenting merge alert, or move conflict buttons into sheet (audit). **YAGNI default:** document follow-up issue if not done here.

- [ ] **Replace-mode confirmation (optional)**  
Second alert or inline checkbox when `importMode == .replace` (audit WCAG 3.3.4). Optional separate PR.

- [ ] **Commit**

```bash
git commit -am "a11y(settings): hint when backup folder import disabled"
```

---

## Plan review loop (skill requirement)

1. After implementation, optionally run **plan-document-reviewer** with this file + PR description as spec.  
2. If reviewer requests changes, update this plan or the PR—not both silently diverging.

---

## Execution handoff

**Plan saved to:** `docs/superpowers/plans/2026-04-03-import-export-settings-polish.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — Use **superpowers:subagent-driven-development**: fresh subagent per task, review between tasks.  
2. **Inline Execution** — Use **superpowers:executing-plans** in one session with checkpoints after each task.

**Which approach?**
