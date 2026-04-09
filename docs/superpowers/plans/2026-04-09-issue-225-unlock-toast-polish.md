# Issue #225: Today bottom unlock toast polish — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After removing the completion-pill hint card, polish `JournalUnlockToastView` and its presentation in `JournalScreen` so the bottom toast carries a clear “you progressed” story (copy, timing, motion, accessibility) without conflicting with the header celebration or App Tour (`JournalTodayOrientationPolicy`).

**Architecture:** Introduce a small **pure timing helper** (new file) for auto-dismiss duration by `JournalCompletionLevel` + `JournalUnlockMilestoneHighlight`; extend `presentUnlockToast` to schedule a cancellable `Task` that calls `dismissUnlockToast()`; optionally stagger toast entrance after `triggerStatusCelebration`. Improve **VoiceOver** by giving the toast button an explicit `accessibilityLabel` derived from the same copy as the view. Tune **English and zh-Hans** strings in `Localizable.xcstrings` for milestone vs generic variants.

**Tech stack:** SwiftUI, Swift Testing / XCTest (match existing test style in `GraceNotesTests`), String Catalog.

---

## File map

| File | Responsibility |
|------|----------------|
| Create: `GraceNotes/GraceNotes/Features/Journal/Views/JournalUnlockToastTiming.swift` | Pure `autoDismissDelay(...)` + optional `celebrationStaggerDelay(reduceMotion:)` |
| Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` | `@State` task for auto-dismiss; schedule/cancel in `presentUnlockToast` / `dismissUnlockToast*` / rank-down; optional stagger when presenting after `triggerStatusCelebration` |
| Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalUnlockToastView.swift` | Expose `accessibilityAnnouncement` or use computed copy for `accessibilityLabel` on the button from `JournalScreen` |
| Modify: `GraceNotes/GraceNotes/Localizable.xcstrings` | Revised `journal.guidance.*` English + zh-Hans |
| Create: `GraceNotesTests/Features/Journal/JournalUnlockToastTimingTests.swift` | Table-driven tests for durations |
| Reference only: `GraceNotes/GraceNotes/Features/Journal/Tutorial/JournalTodayOrientationPolicy.swift` | Confirm no API change |

---

### Task 1: Timing helper + tests (TDD)

**Files:**

- Create: `GraceNotes/GraceNotes/Features/Journal/Views/JournalUnlockToastTiming.swift`
- Create: `GraceNotesTests/Features/Journal/JournalUnlockToastTimingTests.swift`

- [ ] **Step 1: Write the failing test**

Add the test file (XCTest to match `JournalTodayOrientationPolicyTests`):

```swift
import XCTest
@testable import GraceNotes

final class JournalUnlockToastTimingTests: XCTestCase {

    func test_autoDismissDelay_milestoneFirstFull_longerThanGenericBloom() {
        let generic = JournalUnlockToastTiming.autoDismissDelay(
            level: .bloom,
            milestoneHighlight: .none
        )
        let firstFull = JournalUnlockToastTiming.autoDismissDelay(
            level: .bloom,
            milestoneHighlight: .firstFull
        )
        XCTAssertGreaterThan(firstFull, generic)
    }

    func test_autoDismissDelay_milestoneFirstLeaf_longerThanGenericLeaf() {
        let generic = JournalUnlockToastTiming.autoDismissDelay(
            level: .leaf,
            milestoneHighlight: .none
        )
        let firstLeaf = JournalUnlockToastTiming.autoDismissDelay(
            level: .leaf,
            milestoneHighlight: .firstBalanced
        )
        XCTAssertGreaterThan(firstLeaf, generic)
    }

    func test_celebrationStaggerDelay_reduceMotion_isZero() {
        XCTAssertEqual(
            JournalUnlockToastTiming.celebrationStaggerDelay(reduceMotion: true),
            0,
            accuracy: 0.001
        )
    }

    func test_celebrationStaggerDelay_fullMotion_positive() {
        XCTAssertGreaterThan(
            JournalUnlockToastTiming.celebrationStaggerDelay(reduceMotion: false),
            0
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run on macOS with Xcode:

```bash
grace test --destination 'iPhone 17 Pro@latest' --filter JournalUnlockToastTimingTests
```

Expected: **FAIL** — types `JournalUnlockToastTiming` / methods missing (or build error).

- [ ] **Step 3: Write minimal implementation**

Create `JournalUnlockToastTiming.swift`:

```swift
import Foundation

/// Durations for bottom unlock toast polish (issue #225). Keep magic numbers here only.
enum JournalUnlockToastTiming {

    /// Seconds to wait after `presentUnlockToast` before auto-dismiss via `dismissUnlockToast`.
    static func autoDismissDelay(
        level: JournalCompletionLevel,
        milestoneHighlight: JournalUnlockMilestoneHighlight
    ) -> TimeInterval {
        let milestoneExtra: TimeInterval
        switch milestoneHighlight {
        case .firstOneOneOne, .firstBalanced, .firstFull:
            milestoneExtra = 2.0
        case .none:
            milestoneExtra = 0
        }

        let base: TimeInterval
        switch level {
        case .soil:
            base = 3.0
        case .sprout:
            base = 4.0
        case .twig:
            base = 4.25
        case .leaf:
            base = 4.5
        case .bloom:
            base = 5.0
        }
        return base + milestoneExtra
    }

    /// Delay before showing the toast so header celebration / haptics land first.
    static func celebrationStaggerDelay(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : 0.16
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
grace test --destination 'iPhone 17 Pro@latest' --filter JournalUnlockToastTimingTests
```

Expected: **PASS**

- [ ] **Step 5: Commit**

```bash
git add GraceNotes/GraceNotes/Features/Journal/Views/JournalUnlockToastTiming.swift \
        GraceNotesTests/Features/Journal/JournalUnlockToastTimingTests.swift
git commit -m "feat(journal): add unlock toast timing helper for issue #225"
```

---

### Task 2: `JournalScreen` — stagger + auto-dismiss task

**Files:**

- Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift`

- [ ] **Step 1: Add state**

Near other `@State` tasks (e.g. after `statusCelebrationDismissTask`):

```swift
@State private var unlockToastAutoDismissTask: Task<Void, Never>?
```

- [ ] **Step 2: Cancel task in all dismiss paths**

At the **start** of `dismissUnlockToast` and `dismissUnlockToastAndCelebrationForRankDown`, and at the start of `presentUnlockToast` (before scheduling a new one):

```swift
unlockToastAutoDismissTask?.cancel()
unlockToastAutoDismissTask = nil
```

Use **cancellation-safe** sleep before auto-dismiss so manual dismiss does not race:

```swift
do {
    try await Task.sleep(for: .seconds(delay))
} catch {
    return
}
```

- [ ] **Step 3: Schedule auto-dismiss after present**

Replace the body of `presentUnlockToast` with stagger + delayed present + auto-dismiss:

```swift
func presentUnlockToast(
    for level: JournalCompletionLevel,
    milestoneHighlight: JournalUnlockMilestoneHighlight
) {
    unlockToastAutoDismissTask?.cancel()
    unlockToastAutoDismissTask = nil

    let stagger = JournalUnlockToastTiming.celebrationStaggerDelay(reduceMotion: reduceMotion)
    let delay = JournalUnlockToastTiming.autoDismissDelay(
        level: level,
        milestoneHighlight: milestoneHighlight
    )

    unlockToastAutoDismissTask = Task { @MainActor in
        if stagger > 0 {
            try? await Task.sleep(for: .seconds(stagger))
        }
        guard !Task.isCancelled else { return }
        let entrance = reduceMotion ? nil : AppTheme.unlockToastEntranceAnimation(for: level)
        withAnimation(entrance) {
            unlockToastLevel = level
            unlockToastMilestone = milestoneHighlight
            unlockToastScrollBaseline = journalScrollOffsetY
        }
        do {
            try await Task.sleep(for: .seconds(delay))
        } catch {
            return
        }
        dismissUnlockToast()
    }
}
```

**Note:** If product prefers showing the toast **immediately** on first milestone only, gate stagger: `milestoneHighlight != .none && !reduceMotion` before applying `stagger`. Document the chosen rule in the PR.

- [ ] **Step 4: Manual sanity**

Run app in Simulator: rank up Today entry, confirm toast appears after brief delay, dismisses automatically, still dismisses on tap outside and scroll.

- [ ] **Step 5: Commit**

```bash
git add GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift
git commit -m "feat(journal): stagger and auto-dismiss unlock toast (issue #225)"
```

---

### Task 3: Accessibility — label on toast control

**Files:**

- Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalUnlockToastView.swift`
- Modify: `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` (button label)

- [ ] **Step 1: Expose announcement string from `JournalUnlockToastView`**

Add a `static` or instance method that mirrors `message` for accessibility:

```swift
func accessibilityLabelText() -> String {
    message
}
```

(or make `message` `internal` and read it from a small extension in the same module from `JournalScreen` — avoid duplication.)

- [ ] **Step 2: Apply on the `Button` in `journalToastOverlay`**

```swift
Button {
    dismissUnlockToastIfNeeded()
} label: {
    JournalUnlockToastView(level: toastLevel, milestoneHighlight: unlockToastMilestone)
}
.buttonStyle(.plain)
.accessibilityLabel(
    JournalUnlockToastView.accessibilityLabel(
        level: toastLevel,
        milestoneHighlight: unlockToastMilestone
    )
)
.accessibilityHint(String(localized: "common.dismiss"))
```

Implement `accessibilityLabel(level:milestoneHighlight:)` as static using the same switch as `message` (extract shared private static if needed to obey DRY).

- [ ] **Step 3: Verify in Simulator**

Settings → Accessibility → VoiceOver → focus toast: hear full message + dismiss hint.

- [ ] **Step 4: Commit**

```bash
git add GraceNotes/GraceNotes/Features/Journal/Views/JournalUnlockToastView.swift \
        GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift
git commit -m "fix(a11y): label journal unlock toast for VoiceOver (issue #225)"
```

---

### Task 4: Copy — `Localizable.xcstrings`

**Files:**

- Modify: `GraceNotes/GraceNotes/Localizable.xcstrings`

- [ ] **Step 1: Edit English strings** (proposal — tighten per Polanyi: acknowledge + light next step)

Suggested replacements (please refine with product):

- `journal.guidance.reachedSproutToday`  
  - **From:** `You reached Sprout today.`  
  - **To:** `Sprout today—you've got one line in each section.`

- `journal.guidance.reachedLeafToday`  
  - **From:** `You reached Leaf today.`  
  - **To:** `Leaf today—three sections, at least three lines each.`

- `journal.guidance.towardLeafShort`  
  - **From:** `Keep going in each section toward Leaf.`  
  - **To:** `Twig today—add a line in each section when you're ready for Leaf.`

- `journal.guidance.reachedBloomToday` — optional small tightening; keep Bloom definition for generic case.

Milestone keys (`firstTimeOneLineEach`, `firstLeafDay`, `firstBloomDay`) — optional shorten first sentence only if QA shows redundancy with toast length + auto-dismiss.

- [ ] **Step 2: Translator pass for zh-Hans**

Update `zh-Hans` `value` for each touched key to match the new English intent (use `.agents/skills/translate/SKILL.md` discipline).

- [ ] **Step 3: Audit**

```bash
grace l10n audit
```

Expected: no missing keys or orphan references.

- [ ] **Step 4: Commit**

```bash
git add GraceNotes/GraceNotes/Localizable.xcstrings
git commit -m "docs(l10n): refine unlock toast copy for issue #225"
```

---

### Task 5: Regression guard — orientation policy

**Files:**

- Reference: `GraceNotesTests/Features/Journal/JournalTodayOrientationPolicyTests.swift`

- [ ] **Step 1: Run existing tests**

```bash
grace test --destination 'iPhone 17 Pro@latest' --filter JournalTodayOrientationPolicyTests
```

Expected: **PASS** (no code changes expected).

- [ ] **Step 2: If any stagger/tour race appears in QA**, add a comment in `JournalTodayOrientationPolicy.swift` documenting that toast timing does not affect suppression; do not widen scope without a new issue.

---

### Task 6: Verification and PR

- [ ] **Step 1: Lint**

```bash
swiftlint lint
```

- [ ] **Step 2: Full unit suite (local)**

```bash
grace test --destination 'iPhone 17 Pro@latest'
```

- [ ] **Step 3: Open PR** linking `Fixes #225` or `Refs #225` per release practice; attach before/after screen recording for one milestone and one generic rank-up.

---

## Self-review (plan)

1. **Spec coverage:** Copy, timing, motion, a11y, tour boundary, tests — yes.
2. **Placeholders:** None; numeric tuning explicit in Task 1.
3. **Consistency:** `JournalUnlockMilestoneHighlight.firstBalanced` maps to “first Leaf” in evaluator — timing uses milestone enum correctly alongside `level`.

---

## Execution handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-09-issue-225-unlock-toast-polish.md`. Two execution options:**

1. **Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration (`superpowers:subagent-driven-development`).

2. **Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

**Which approach?**
