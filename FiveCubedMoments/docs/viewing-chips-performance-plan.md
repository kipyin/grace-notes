# Viewing Chips Performance — Implementation Plan

Implementation plan for fixing slowness when switching between chips (Gratitudes, Needs, People). Addresses both chip-tap switching and History list performance.

---

## Problem Summary

When switching viewing chips (tapping from one chip to another to edit), the app blocks until summarization completes. With cloud summarization enabled, this means a network round-trip (500ms–3s) before the switch. Even with on-device NL, there is noticeable delay. The user perceives: **tap chip → pause → switch**.

---

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Immediate switch vs. wait** | Switch immediately | User expects instant feedback. Persisting/summarizing can complete in background. |
| **Interim chip label when text changed** | First 20 chars | Display something immediately while background summarization runs. Matches existing fallback in `JournalViewModel` and `CloudSummarizer`. Avoids showing a stale/wrong label (e.g., "Family" when user changed to "Coffee with mom"). |
| **Unchanged-text check** | Compare trimmed input to stored fullText | Avoids redundant summarization and persist when user tapped away without editing. Same check covers both "skip update" and "reuse chipLabel" logic. |
| **History groupedByMonth** | Cache in @State, invalidate on entries change | Prevents recomputing O(n) grouping on every body evaluation when History tab is visible. |

---

## Fix 1: Switch Immediately, Run Summarization in Background

**Goal:** Do not block chip switch on summarization. Update the model and UI right away; summarize and persist in the background.

### Current Flow (blocking)
1. User taps chip B while editing chip A.
2. `chipTapped` calls `await viewModel.updateGratitude(at:currentIndex, fullText:input)`.
3. `updateGratitude` awaits `summarizeForChip`, then updates model and schedules persist.
4. Only after that does `chipTapped` set `editingIndex` and `inputText` for chip B.

### New Flow (immediate switch)
1. User taps chip B while editing chip A.
2. **Immediately:** Update model with new `fullText`, interim chip label (first 20 chars), and `isTruncated`. Update `editingIndex` and `inputText` for chip B. Switch completes.
3. **Background:** Run summarization off the main actor; when done, hop to main actor to apply `chipLabel` and `isTruncated`, then schedule autosave.

### Implementation

**JournalViewModel** — Add fast-path methods that do not await summarization:

- `updateGratitudeImmediate(at:fullText:)` — Updates `gratitudes[index]` with fullText, `chipLabel: String(fullText.prefix(20))`, `isTruncated: fullText.count > 20`. Schedules autosave. Returns the index updated (for background task).
- `addGratitudeImmediate(_:)` — Appends new item with first 20 chars as interim label. Schedules autosave. Returns the new index.
- Same for needs and people.

- `summarizeAndUpdateChip(section:index:)` — Async method. **Run summarization off the main actor** to avoid UI hitches (especially from synchronous NL work): capture a snapshot of the item's `fullText`, use `Task.detached` or a nonisolated helper to call the summarizer, then `await MainActor.run` to apply `chipLabel` and `isTruncated` and call `scheduleAutosave()`. Do not run summarization on the main actor.

**JournalViewModel** — Optional refactor: introduce shared helpers to reduce duplication across the six methods (update/add × gratitudes/needs/people).

**JournalScreen** — In `chipTapped`:

- When input has text and we need to save:
  - **Editing existing chip:** Call `updateGratitudeImmediate(at:fullText:)` (or equivalent); fire `Task { await viewModel.summarizeAndUpdateChip(...) }` without awaiting.
  - **Adding new chip:** Call `addGratitudeImmediate(input)` (or equivalent); fire `Task { await viewModel.summarizeAndUpdateChip(section:index: newIndex) }` without awaiting.
- Set `editingIndex`, `inputText` for the tapped chip immediately (no `await` before).

**Files:**
- `FiveCubedMoments/FiveCubedMoments/Features/Journal/ViewModels/JournalViewModel.swift`
- `FiveCubedMoments/FiveCubedMoments/Features/Journal/Views/JournalScreen.swift`

---

## Fix 2: Skip Summarization When Switching Focus Without Text Changes

**Goal:** If the user taps another chip without editing (input matches stored fullText), skip update and persist entirely. Switch immediately.

### Logic
Before calling any update:
- If switching from an existing chip (e.g. `editingGratitudeIndex != nil`), unwrap the index and compare: `let trimmed = inputText.trimmingCharacters(...)` and `let stored = viewModel.fullTextForGratitude(at: idx) ?? ""`; if `trimmed == stored`, skip update.
- Same check for needs and people.

### Implementation

**JournalScreen** — In `chipTapped`, before the "has unsaved text" branch:
- When switching from an existing chip (`editingGratitudeIndex != nil`), unwrap the index, compute `trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)`, and `stored = viewModel.fullTextForGratitude(at: currentIndex) ?? ""`. If `trimmed == stored`, set `editingIndex` and `inputText` for the new chip and return (no Task, no update).
- Same for need and person sections.

**JournalViewModel** — No changes required for this fix; the check lives in the view layer.

**Files:**
- `FiveCubedMoments/FiveCubedMoments/Features/Journal/Views/JournalScreen.swift`

---

## Fix 3: Reuse Existing chipLabel When fullText Unchanged

**Goal:** In the ViewModel’s update path, if the new fullText (trimmed) equals the existing item’s fullText, do not call summarization. Return success and keep the existing chipLabel. Defensive guard against redundant work.

### Logic
In `updateGratitude`, `updateNeed`, `updatePerson` (and in the new immediate-update path if we keep a sync variant):
- Before calling `summarizeForChip`, compare `trimmed` to `gratitudes[index].fullText`.
- If equal, update only if something else changed (e.g. whitespace), or simply return `true` without re-summarizing. For the immediate-update flow, this means we might not need to fire a background task at all when text is unchanged.

### Interaction with Fix 1 and 2
- Fix 2 runs in the view and skips the entire update when input matches stored fullText.
- Fix 3 is a ViewModel guard: if an update is requested but fullText is unchanged, skip summarization and persist. Covers edge cases (e.g. double-tap, programmatic calls).

### Implementation

**JournalViewModel** — In `updateGratitude`, `updateNeed`, `updatePerson`:
- After validation, add: `guard trimmed != gratitudes[index].fullText else { return true }` (or equivalent for needs/people).
- If unchanged, we could still persist (in case of whitespace normalization) — but that would require updating the item. Simpler: if `trimmed == existing.fullText`, return `true` without any model change. The view already skipped the update via Fix 2, so this is mostly defensive.

**JournalViewModel** — In the new `summarizeAndUpdateChip` (background task):
- Before calling `summarizeForChip`, check if `gratitudes[index].fullText` still matches what we think we’re summarizing. If the user rapidly switched chips again, the item might have been updated. Optionally skip if we're summarizing text that’s already summarized (e.g. compare to a snapshot). For simplicity, we can run summarization; the main win is from Fix 1 and 2. Fix 3 in the sync update methods is the key — those are still used by Submit (Enter key). When user presses Enter, we call `updateGratitude`. If they didn’t change the text, we’d skip summarization. Good.

**Files:**
- `FiveCubedMoments/FiveCubedMoments/Features/Journal/ViewModels/JournalViewModel.swift`

---

## Fix 4: History groupedByMonth Caching (Bonus)

**Goal:** Avoid recomputing `groupedByMonth` on every History view body evaluation. With many entries, the Dictionary grouping and sort add cost.

### Implementation

**HistoryScreen** — Cache `groupedByMonth` result:
- Add `@State private var cachedGroupedByMonth: [(key: Date, entries: [JournalEntry])] = []`.
- Use `.onChange(of: entries.count)` or `.onAppear` plus `.onChange(of: entries.map(\.id))` to recompute when entries change. Simpler: use `onChange(of: entries)` — but `entries` is an array, so we need a stable trigger. Use `onChange(of: entries.count)` and `onAppear` as a baseline; if entries change without count change (e.g. in-place update), we might miss. Alternatively, use a computed property that depends on `entries` but memoize with a cache key. SwiftUI doesn’t have built-in memoization. A cleaner approach: use `let grouped = ...` computed from `entries` but have the ForEach iterate over something cheaper. Actually the issue is the computed property runs every time `historyList` is evaluated. We could move the grouping into a dedicated view that receives `entries` and only recomputes when `entries` changes — that’s automatic if we pass `entries` as a let. The ForEach will re-run when `groupedByMonth` changes. The real problem is `groupedByMonth` is called every time the parent view body runs. We need to ensure it’s only recomputed when `entries` changes. One approach: `@State private var grouped: [(key: Date, entries: [JournalEntry])]` and in `.task(id: entries.count)` or `.onChange(of: entries)` recompute. But `entries` is `[JournalEntry]` — onChange may not work well for array identity. `.task(id: entries.map(\.id))` — that creates a new array every time. Simpler: keep the computed property but ensure HistoryScreen’s body doesn’t re-run unnecessarily. The @Query already drives updates. Perhaps the cost is acceptable for typical entry counts (< 100). Document as a future optimization if profiling shows it matters.

**Simpler approach:** Convert `groupedByMonth` to a method that takes `entries` and returns the result. The caller passes `entries`. SwiftUI will re-evaluate when `entries` changes (from @Query). The computed property itself isn’t the issue — it’s that it runs on every body evaluation. The real fix: `List { ForEach(...) }` will re-render when `groupedByMonth` returns different value. The work is O(n). For n=100, it’s negligible. For n=1000, it might matter. Add a cache: `@State private var lastEntryCount: Int = -1` and `@State private var cachedGroups: [...]`. When `entries.count != lastEntryCount` or we detect a change, recompute. This adds complexity. Recommendation: **Implement only if profiling shows History as a bottleneck.** For now, note it in the plan as an optional follow-up.

**Files:**
- `FiveCubedMoments/FiveCubedMoments/Features/Journal/Views/HistoryScreen.swift` (optional)

---

## Implementation Order

1. **Fix 2** — Skip when text unchanged. Simplest, no new APIs, immediate win for common case (tap away without editing).
2. **Fix 3** — Reuse chipLabel guard in ViewModel. Small addition to update methods.
3. **Fix 1** — Immediate switch + background summarization. Biggest change; depends on understanding the sync vs async flow.
4. **Fix 4** — History cache. Optional; do after profiling if needed.

---

## Testing

- **Fix 2:** Tap chip A, tap chip B without editing. Switch should be instant. Tap chip A, edit text, tap chip B. Should save (Fix 1 applies).
- **Fix 3:** Submit (Enter) without changing text. Should not call summarization (if that code path is hit). Unit test: `updateGratitude(at: 0, fullText: existingFullText)` returns true, no summarizer call.
- **Fix 1:** Tap chip A, edit, tap chip B. Verify: (a) switch is immediate, (b) chip A shows interim label (first 20 chars) briefly, then correct label when summary arrives, (c) persist eventually happens. With cloud summarization, switch should be instant; label may update 1–2s later.
- **Existing tests:** Ensure `JournalViewModelTests` still pass. Add tests for skip-when-unchanged and immediate-update paths if feasible.

---

## Files Touched

| File | Changes |
|------|---------|
| `JournalViewModel.swift` | Fix 1: `updateGratitudeImmediate` (and need/person), `summarizeAndUpdateChip`. Fix 3: guard in update methods. |
| `JournalScreen.swift` | Fix 1: Use immediate update + background task. Fix 2: Skip-update check before save. |
| `JournalViewModelTests.swift` | New tests for unchanged-text skip, optional tests for immediate update. |
| `HistoryScreen.swift` | Fix 4 (optional): Cache groupedByMonth. |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Background summarization fails | Existing error handling in summarizeForChip; fallback to first-N. Interim label remains. Log failure. |
| Rapid chip switching | Each switch fires a new background task. If user switches A→B→C quickly, we may have multiple in-flight summaries for different indices. Use task cancellation or a serial queue to avoid races. Simple approach: don’t cancel; last write wins. The item at a given index is updated; if user switched away, the old index’s summary completing is harmless. |
| Persist before summary | We persist immediately with fullText and interim label. When summary completes, we update chipLabel and persist again. Two persists are acceptable; autosave debounce will coalesce if close together. |

---

## Summary

| Fix | Description | Effort |
|-----|-------------|--------|
| 1 | Immediate switch + background summarization | Medium |
| 2 | Skip update when input matches stored fullText | Low |
| 3 | ViewModel guard: no summarization when fullText unchanged | Low |
| 4 | History groupedByMonth cache | Low (optional) |

Implementing Fixes 1–3 gives maximum performance improvement for chip switching. Fix 4 can follow if History proves slow with large datasets.
