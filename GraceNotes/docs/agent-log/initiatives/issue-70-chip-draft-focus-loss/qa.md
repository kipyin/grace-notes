---
initiative_id: issue-70-chip-draft-focus-loss
role: QA Reviewer
status: in_progress
updated_at: 2026-03-22
related_issue: 70
related_pr: 77
---

# QA — Issue #70: Chip draft commit on focus loss

## Inputs reviewed

- [GitHub issue #70](https://github.com/kipyin/grace-notes/issues/70) (problem, proposal, acceptance)
- Architect-style close criteria from planning thread (blur commit, empty draft, Return unchanged, `isTransitioning`, keyboard when moving to other text fields)
- In-repo implementation on branch `cursor/issue-70-planning-9b4d`: `JournalScreen.swift`, `SequentialSectionView.swift`, `EditableTextSection.swift`, `JournalScreenChipHandling.swift`
- No `brief.md` / `architecture.md` / `testing.md` in this initiative folder yet (none were created for #70)

## Requirement coverage

| Intent | Status |
|--------|--------|
| Non-empty trimmed draft commits when chip field loses focus (same path as Return / `submitChipSection`) | **Met in code** — `onInputFocusLost` → `commitChipDraftOnInputFocusLost` → `submitChipSection` |
| Empty / whitespace-only draft does not create a chip | **Met** — trim guard in `submitChipSection` before `beginTransition` |
| Return key behavior unchanged | **Met** — still `onSubmit` → `submit(section:)` → `submitChipSection`; empty early-out does not change Return semantics for non-empty |
| Respect `isTransitioning` / avoid double-commit | **Met** — `beginTransition` unchanged; empty blur no longer toggles transition |
| Keyboard remains when user moves to another journal text field | **Partially evidenced** — `Task.yield` then `restoreKeyboardFocusIfAnotherJournalTextFieldIsActive()` for chip fields + Reading Notes + Reflections; **not verified on device** |

## Behavior and regression risks

1. **Focus timing (medium):** Restoration depends on `@FocusState` being `true` for the destination field after one `Task.yield`. `TextEditor` focus can lag behind `TextField` focus in SwiftUI; risk of keyboard dismissing briefly or `restoreInputFocus` not running when the user intended Reading Notes / Reflections. Needs Simulator confirmation.
2. **Order of events on Return (low):** If focus drops to `false` after a successful Return submit, `onInputFocusLost` may still run; draft is already empty so `submitChipSection` returns `false` — no duplicate chip. Acceptable.
3. **Blur with no text target (by design):** Tapping chrome / scrolling / dismissing keyboard does not restore chip focus — aligns with stated PR note; confirm product is OK vs. “always keep keyboard.”
4. **`performChipTap` / `(+)` flows (low):** Unchanged; still use existing handlers with their own transition guards.

## Code quality gaps

- `SequentialSectionView` remains over the default `type_body_length` threshold; localized `swiftlint:disable` documents the debt but does not reduce structural size — acceptable short-term, not a correctness issue.
- Focus restoration duplicates the list of journal text fields in one method — clear but must stay in sync if new focused editors are added (minor maintainability note).

## Test gaps

- **No automated tests** for focus-driven commit or keyboard restoration (expected on Linux CI; SwiftUI + `FocusState` are poor fits for current test target anyway).
- **Required before merge:** Manual Simulator passes for issue acceptance: chip → other chip, chip → Reading Notes, chip → Reflections, whitespace-only blur, Return still commits, optional VoiceOver spot-check per issue note.

## Decision

**Fail (pending verification)**

Implementation matches stated product and technical scope on code review, but **acceptance criteria are not satisfied with objective evidence** in this environment (no iOS Simulator run; focus/keyboard behavior is high-risk for timing).

## Rationale

`submitChipSection` ordering fix and blur wiring are sound. The remaining gap is **empirical validation** of focus restoration across `TextField` → `TextEditor` and multi-chip moves.

## Open questions

- After Simulator runs, does a single `Task.yield` reliably pick up `isReadingNotesFocused` / `isReflectionsFocused` on older devices or with Reduce Motion / keyboard accessories?
- Should `initiatives/issue-70-chip-draft-focus-loss/` gain a minimal `brief.md` / `testing.md` for continuity (optional hygiene)?

## Next owner

- **`Test Lead`:** Execute the manual matrix above on macOS + Simulator; file results or defects.
- **`Builder`:** Only if Simulator finds focus/keyboard gaps (e.g. second yield, explicit focus binding order).

---

## Builder follow-up (2026-03-22)

Addressed without Simulator (Linux):

- **Focus timing:** `commitChipDraftOnInputFocusLost` now retries restoration after a **second** `Task.yield` when the first pass finds no focused journal field—targets `TextEditor` lag vs chip `TextField`.
- **Maintainability:** `restoreKeyboardFocusIfAnotherJournalTextFieldIsActive()` uses a single `candidates` list with an inline note to add future focused editors there only.
- **Continuity:** `brief.md` added in this initiative folder (per open question).

**SequentialSectionView `type_body_length`:** Still over threshold with scoped lint disable; QA rated acceptable short-term; no structural split in this pass.

**Decision unchanged:** Fail (pending verification) until Test Lead signs off on device.
