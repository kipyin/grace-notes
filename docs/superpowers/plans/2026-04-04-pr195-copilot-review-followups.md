# PR 195 Copilot review follow-ups — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the seven GitHub Copilot inline review threads on [PR 195](https://github.com/kipyin/grace-notes/pull/195) (backup/import work) with verified behavior and tests where applicable.

**Architecture:** Prefer small, localized changes: adjust `ScheduledBackupRunner` / `ScheduledBackupPreferences` for failure bookkeeping and threading; fix backup-folder import by keeping security-scoped **folder** access around file reads; add string-catalog pluralization and pure `ScheduledBackupInterval` unit tests.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest, String Catalog (`Localizable.xcstrings`).

---

## File map

| File | Responsibility |
|------|------------------|
| `GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupRunner.swift` | When/how scheduled export runs; history + `lastRunAt` updates |
| `GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupPreferences.swift` | Bookmarks, interval, `isDue`, stale bookmark handling |
| `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsSupport.swift` | `BackupFolderImportFileListView` — folder scope for listing |
| `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift` | `runManualImport` — file read path for backup-folder URLs |
| `GraceNotes/GraceNotes/Localizable.xcstrings` | Merge-conflict message pluralization |
| `GraceNotesTests/.../ScheduledBackupIntervalTests.swift` (new) | `ScheduledBackupInterval.isDue` boundaries |

---

### Task 1: Security-scoped backup-folder import (thread [#discussion_r3033051809](https://github.com/kipyin/grace-notes/pull/195#discussion_r3033051809))

**Problem:** `BackupFolderImportFileListView.load()` stops folder access before the user selects a child URL; `runManualImport` calls `startAccessingSecurityScopedResource()` on the **file** URL, which often fails for directory-derived URLs.

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsSupport.swift` (optional: document contract)
- Modify: `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift`

**Approach:** Before `Data(contentsOf: url)` for imports whose URL lives under the bookmarked backup folder, `resolveFolderURL()`, `startAccessingSecurityScopedResource()` on the **folder**, read file data (or open input stream) while access is held, then `stopAccessing`. Keep existing file-URL path for document-picker imports. Consider a small helper `ScheduledBackupPreferences.withResolvedFolderAccess<T>(_ body: (URL) throws -> T) rethrows -> T` to avoid duplicating resolve/start/stop.

- [ ] **Step 1:** Add helper or inline folder-scoped read in `runManualImport` when `url` is under resolved folder (compare standardized path prefixes or use `url.path.hasPrefix(folderURL.path)` with careful trailing-slash normalization).
- [ ] **Step 2:** Manual smoke: pick iCloud backup folder, list JSON, import one file — confirm no permission error.

---

### Task 2: Stale bookmark refresh (thread [#discussion_r3033051793](https://github.com/kipyin/grace-notes/pull/195#discussion_r3033051793))

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupPreferences.swift`

- [ ] **Step 1:** When `bookmarkDataIsStale` is true after resolve, call `try storeFolderBookmark(for: url)` (refresh persisted bookmark) instead of throwing `staleBookmark`, then return `url`.
- [ ] **Step 2:** If `storeFolderBookmark` throws, fall back to existing error behavior (or map to `staleBookmark` / user-facing folder error).

---

### Task 3: Failed attempts — history + short backoff + Settings-only cue (threads [#discussion_r3033051760](https://github.com/kipyin/grace-notes/pull/195#discussion_r3033051760), [#discussion_r3033051776](https://github.com/kipyin/grace-notes/pull/195#discussion_r3033051776))

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupRunner.swift`
- Modify: `ScheduledBackupPreferences` — add `lastFailedAttemptAt` (or equivalent) + **failure backoff interval** constant (~30–60 min); extend `isDue` to respect “not until backoff elapsed since last failed attempt” (success path still uses `lastRunAt` / normal interval).
- Modify: `ImportExportSettingsScreen.swift` (and strings) — optional footnote / subtle row cue when last scheduled failure is newer than last success (see “Failure UX ideas” in Decisions).

- [ ] **Step 1:** On `resolveFolderURL()` failure: `BackupExportHistoryStore.record(success: false, …)`; set `lastFailedAttemptAt = now` (do **not** advance `lastRunAt` on failure unless product chooses to treat it as “interval consumed” — **prefer** separate failure clock).
- [ ] **Step 2:** On `startAccessingSecurityScopedResource() == false`: same as Step 1.
- [ ] **Step 3:** In export `catch` block: same as Step 1; on **success**, clear or obsolete the failure cue by updating `lastRunAt` and leaving history as-is.
- [ ] **Step 4:** Implement Settings-only visibility (footnote or tint) tied to history / `lastFailedAttemptAt` vs last success — **no** app-wide banner.

---

### Task 4: Main-thread export work (thread [#discussion_r3033051744](https://github.com/kipyin/grace-notes/pull/195#discussion_r3033051744))

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Settings/Services/ScheduledBackupRunner.swift`
- Verify call site: `GraceNotes/GraceNotes/Application/GraceNotesApp.swift` (or scene phase hook)

- [ ] **Step 1:** Remove `@MainActor` from `runIfDue` (or split: lightweight gatekeeping on MainActor, heavy work in `Task.detached` / nonisolated async with dedicated `ModelContext`).
- [ ] **Step 2:** Perform `exportArchiveFile` and file copy off main; hop to `MainActor` only for `BackupExportHistoryStore.record` and `ScheduledBackupPreferences.lastRunAt` writes.
- [ ] **Step 3:** Manual or instrument check: foreground activation should not hitch visibly on medium DB sizes.

---

### Task 5: Merge conflict copy — singular/plural (thread [#discussion_r3033051821](https://github.com/kipyin/grace-notes/pull/195#discussion_r3033051821))

**Files:**
- Modify: `GraceNotes/GraceNotes/Localizable.xcstrings` — `DataPrivacy.import.mergeConflict.message` → `variations.plural` for `en` and `zh-Hans`
- Modify: `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift` — replace `String(format: …)` with `String(localized:format:)` / `String.init(localized:defaultValue:)` that supports plural if needed (Xcode 15+ string catalog API)

- [ ] **Step 1:** Add English `one` vs `other` strings (grammar fixes for “1 journal day”).
- [ ] **Step 2:** Add zh-Hans plural variants (even if copy is identical, catalog should define both keys if required by format).
- [ ] **Step 3:** Update Swift call site to pass `mergeConflictDays.count` as plural-aware argument per Apple docs.

---

### Task 6: `ScheduledBackupInterval.isDue` unit tests (thread [#discussion_r3033051842](https://github.com/kipyin/grace-notes/pull/195#discussion_r3033051842))

**Files:**
- Create: `GraceNotesTests/Features/Settings/ScheduledBackupIntervalTests.swift` (path aligned with existing `JournalDataImportServiceTests.swift` location)
- Ensure target membership: `GraceNotesTests`

- [ ] **Step 1:** Fixed `Calendar` + `TimeZone` (e.g. `America/Los_Angeles`) to assert stable day boundaries for `.daily` (same calendar day → false; next calendar day → true when `lastRun` is start-of-day).
- [ ] **Step 2:** `.weekly` / `.biweekly` / `.monthly` — boundary at exact day delta (e.g. 6 vs 7, 13 vs 14, 29 vs 30).
- [ ] **Step 3:** `lastRun == nil` → `true` for non-`.off`.
- [ ] **Step 4:** Run `grace test` (macOS) or Xcode test for `GraceNotesTests`.

---

## Self-review (spec coverage)

| Copilot thread | Task |
|----------------|------|
| Main-thread stall | Task 4 |
| Silent failures before export | Task 3 |
| Failure without `lastRunAt` | Task 3 |
| Stale bookmark | Task 2 |
| Backup-folder sandbox read | Task 1 |
| Plural grammar | Task 5 |
| `isDue` tests | Task 6 |

---

## Decisions (2026-04-04, from product)

1. **Failure retry + visibility:** Use a **short failure backoff** (separate from successful `lastRunAt`) so retries are not every activation, but **do not** use global in-app banners. Surface problems **only in Settings → Import & Export** (see “Failure UX ideas” below).
2. **Stale bookmark:** **Auto-refresh** when resolve reports `bookmarkDataIsStale` — call `storeFolderBookmark(for: url)` and continue; if refresh fails, show existing folder error UX and **do not** loop silently.
3. **Merge scope:** **Single larger PR** is OK — include Task 4 (off-main export) in the same batch.

### Failure UX ideas (no app-wide banners)

- **Export history as the log:** Failed scheduled rows already land in history; ensure the Import & Export screen makes **the most recent failure** easy to notice (e.g. short **footnote** under Scheduled backup: “Last backup failed — tap Export history” when `lastFailureAt` is newer than last success, without a modal).
- **Optional subtle chrome:** A small **non-modal** cue next to “Scheduled backup” or “Export history” (text tint or “!” in the chevron row) **only while** there is an unresolved failed attempt since last success — clears when the next scheduled run succeeds or the user re-picks the folder.
- **One row, not a toast:** Tapping **Export history** is the intentional drill-down; no banner on the journal tab.
- **Backoff constants:** e.g. **`lastFailureAttemptAt` + 1 hour** (or 30 min) before `isDue` considers another try — tunable constant, documented in code. Still **record** each failure in `BackupExportHistoryStore` when an attempt actually runs.

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-04-04-pr195-copilot-review-followups.md`.

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks.

**2. Inline execution** — Same session with checkpoints after Tasks 1–2, 3, 4, etc.

**Which approach?**
