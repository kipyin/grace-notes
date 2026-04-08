# Guided journal keyboard + scroll (issue #233) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the People strip losing keyboard focus after the first keystroke during the guided Today journal flow, and scroll the journal so the next focused section is centered or clearly visible above the keyboard when onboarding auto-advances focus.

**Architecture:** The Today `ScrollView` uses `.scrollDismissesKeyboard(.immediately)` while chip typing schedules programmatic `ScrollViewProxy.scrollTo` via `JournalKeyboardScrollCoordinator` (`typing` reason). On lower sections (People), caret-visibility often does not skip that scroll; the resulting programmatic scroll is treated like a scroll that should dismiss the keyboard immediately, so the first character triggers focus loss. Mitigate by aligning scroll-dismiss policy with how `ReviewScreen` narrows `.never` while search is focused (see `ReviewScreen.swift`), or by switching the journal scroll view to a mode where programmatic scroll does not dismiss the keyboard (prefer `.interactively` first; validate manually). For auto-advanced onboarding focus, wire the same path as Reading Notes / Reflections: on chip `FocusState` transitions to focused, call `scheduleJournalKeyboardScroll` with `.focusChanged` and a **center** anchor for sentence-chip targets so the active field lands in a comfortable viewport.

**Tech Stack:** SwiftUI, iOS 18+ journal host, existing `JournalKeyboardScrollCoordinator` / `JournalScrollTarget`, no new dependencies.

**Tracked issue:** [kiyin/grace-notes#233](https://github.com/kipyin/grace-notes/issues/233)

---

## File structure

| File | Role |
|------|------|
| `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` | `scrollDismissesKeyboard`, keyboard overlap handlers, chip sections, `focusOnboardingStep*`; add `onChange` for chip focus → scroll. |
| `GraceNotes/GraceNotes/Features/Journal/Views/JournalKeyboardScrollSupport.swift` | Optional: extract `unitPointAnchor(reason:scrollTarget:)` for tests; extend coordinator to use per-reason anchor (center for chip `focusChanged`). |
| `GraceNotesTests/Features/Journal/JournalKeyboardScrollCoordinatorTests.swift` | **Create** — unit tests for anchor selection logic (pure, runs in `GraceNotesTests` on macOS CI). |

---

### Task 1: Anchor policy helper (testability)

**Files:**
- Create: `GraceNotesTests/Features/Journal/JournalKeyboardScrollCoordinatorTests.swift`
- Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalKeyboardScrollSupport.swift` (`JournalKeyboardScrollCoordinator`)

- [ ] **Step 1: Write the failing test**

Create `GraceNotesTests/Features/Journal/JournalKeyboardScrollCoordinatorTests.swift`:

```swift
import XCTest
@testable import GraceNotes

final class JournalKeyboardScrollCoordinatorTests: XCTestCase {
    func test_scrollAnchor_focusChanged_sentenceChips_usesCenter() {
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.peopleInputArea),
                scrollTarget: .peopleInputArea
            ),
            UnitPoint.center
        )
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.needInputArea),
                scrollTarget: .needInputArea
            ),
            UnitPoint.center
        )
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.gratitudeSection),
                scrollTarget: .gratitudeSection
            ),
            UnitPoint.center
        )
    }

    func test_scrollAnchor_focusChanged_notes_usesBottom() {
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.readingNotes),
                scrollTarget: .readingNotes
            ),
            UnitPoint.bottom
        )
    }

    func test_scrollAnchor_typing_usesBottom() {
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .typing(.peopleInputArea),
                scrollTarget: .peopleInputArea
            ),
            UnitPoint.bottom
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (macOS, Xcode — from repo root or Xcode UI):

```bash
xcodebuild test -scheme GraceNotes -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:GraceNotesTests/JournalKeyboardScrollCoordinatorTests 2>&1
```

Expected: **FAIL** — `JournalKeyboardScrollCoordinator.scrollAnchor` does not exist (or does not compile).

- [ ] **Step 3: Add `scrollAnchor` and use it in `scheduleScrollAdjust`**

In `JournalKeyboardScrollSupport.swift`, inside `enum JournalKeyboardScrollCoordinator`, add:

```swift
static func scrollAnchor(
    for reason: JournalKeyboardScrollReason,
    scrollTarget: JournalScrollTarget
) -> UnitPoint {
    switch reason {
    case .focusChanged:
        switch scrollTarget {
        case .gratitudeSection, .needInputArea, .peopleInputArea:
            return .center
        case .completionHeader, .sentenceSections, .readingNotes, .reflections:
            return .bottom
        }
    case .keyboardDidChangeFrame, .typing, .newlineAdded:
        return .bottom
    }
}
```

Replace the line `let anchor = UnitPoint.bottom` in `scheduleScrollAdjust` with:

```swift
let anchor = scrollAnchor(for: request.reason, scrollTarget: scrollTarget)
```

- [ ] **Step 4: Run tests — expect PASS**

Same `xcodebuild` command as Step 2.

Expected: **PASS**

- [ ] **Step 5: Commit**

```bash
git add GraceNotes/GraceNotes/Features/Journal/Views/JournalKeyboardScrollSupport.swift GraceNotesTests/Features/Journal/JournalKeyboardScrollCoordinatorTests.swift
git commit -m "test(journal): scroll anchor helper for keyboard coordinator"
```

---

### Task 2: Stop keyboard dismiss on programmatic chip scroll

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` (inside `journalScrollViewWithModifiers`, the `ScrollView` modifier chain near `.scrollDismissesKeyboard(.immediately)`)

- [ ] **Step 1: Change scroll-dismiss mode**

Locate the `ScrollView` block that ends with:

```swift
.scrollDismissesKeyboard(.immediately)
```

**First attempt (preferred):** replace with:

```swift
.scrollDismissesKeyboard(.interactively)
```

**If manual verification shows user drag no longer dismisses keyboard when desired:** adopt the same conditional pattern as `ReviewScreen.swift` (search field): use `.never` while **any** journal text field is focused (reuse `isAnyJournalFieldFocused` from `JournalScreen`), and `.immediately` otherwise, e.g.:

```swift
.scrollDismissesKeyboard(isAnyJournalFieldFocused ? .never : .immediately)
```

Only introduce the conditional if `.interactively` fails acceptance (document the outcome in the PR).

- [ ] **Step 2: Manual verification (issue acceptance 1)**

On Simulator or device, reset guided journal / fresh Today onboarding path:

1. Complete Gratitude → advance to Needs → complete Need → advance to **People**.
2. Focus People composer; type **multiple characters** without pausing.

Expected: keyboard **stays up**; text accumulates; no dismiss after the first character.

Run lint:

```bash
cd /Users/kip/Code/grace-notes && swiftlint lint
```

Expected: no new violations in edited files.

- [ ] **Step 3: Commit**

```bash
git add GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift
git commit -m "fix(journal): avoid keyboard dismiss when scrolling chip editors (#233)"
```

---

### Task 3: Scroll to chip section when focus moves (guided advance)

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` — in `journalScrollViewWithModifiers`, alongside existing `.onChange(of: isReadingNotesFocused)` / `isReflectionsFocused`, add chip focus observers that call `scheduleJournalKeyboardScroll` with `reason: .focusChanged(...)`.

- [ ] **Step 1: Add onChange handlers for chip FocusState**

In `journalScrollViewWithModifiers`, after the existing `isReflectionsFocused` onChange (same `proxy` in scope), add:

```swift
.onChange(of: isGratitudeInputFocused) { _, isFocused in
    guard isFocused else { return }
    scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.gratitudeSection))
}
.onChange(of: isNeedInputFocused) { _, isFocused in
    guard isFocused else { return }
    scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.needInputArea))
}
.onChange(of: isPersonInputFocused) { _, isFocused in
    guard isFocused else { return }
    scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.peopleInputArea))
}
```

This covers: initial `focusOnboardingStepIfNeeded`, `focusOnboardingStepForced` after guided chip submit, and normal user taps into a chip field — all use the same scroll policy.

- [ ] **Step 2: Manual verification (issue acceptance 2)**

Guided flow: after submitting Gratitude, when focus jumps to Needs, confirm the Needs composer scrolls to a **comfortable** position (centered per Task 1 anchor) with keyboard visible. Repeat Need → People.

Also spot-check **non-guided** Today entry: tapping into Gratitude / Needs / People still scrolls reasonably.

- [ ] **Step 3: Run tests + lint**

```bash
xcodebuild test -scheme GraceNotes -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:GraceNotesTests 2>&1
swiftlint lint
```

- [ ] **Step 4: Commit**

```bash
git add GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift
git commit -m "fix(journal): scroll focused sentence section into view (#233)"
```

---

## Self-review

**1. Spec coverage**

| Requirement | Task |
|-------------|------|
| People typing without per-keystroke keyboard dismiss | Task 2 (`scrollDismissesKeyboard` / conditional) |
| Auto-advance scrolls next field into view | Task 3 (`onChange` + Task 1 center anchor for `.focusChanged`) |
| Similar sequential strips (Gratitude/Needs) | Task 2–3 apply to all chip composers |

**2. Placeholder scan:** No TBD/TODO in steps; code and commands are concrete.

**3. Type consistency:** `JournalKeyboardScrollReason.focusChanged` already carries `JournalScrollTarget`; `scheduleJournalKeyboardScroll` matches existing call sites for notes.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-08-guided-journal-keyboard-scroll-233.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. **REQUIRED SUB-SKILL:** superpowers:subagent-driven-development.

**2. Inline Execution** — Execute tasks in one session using superpowers:executing-plans with batch checkpoints.

**Which approach?**
