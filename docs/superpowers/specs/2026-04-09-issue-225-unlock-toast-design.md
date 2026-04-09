# Issue #225: Today bottom unlock toast — design (Polanyi lens)

**GitHub:** [kipyin/grace-notes#225](https://github.com/kipyin/grace-notes/issues/225)

**Context:** The dismissible hint card under the completion pill is removed. `JournalUnlockToastView` (bottom sheet toast) plus header celebration (`triggerStatusCelebration`) now carry the “you progressed” story. App Tour suppression remains centralized in `JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast`.

---

## Interview lock-in (requirements)

**Agreed success criteria**

- Bottom toast feels like the **main readable celebration** beside the pill: clear hierarchy between **milestone (first-time)** and **generic tier bump** copy without stacking duplicate teaching.
- **Motion and timing** feel intentional: toast does not fight the short header pulse; users who rely on speech or reduced motion still get a **stable, labeled** control.
- **Dismissal** stays predictable: tap toast, tap outside content, small scroll (existing `unlockToastScrollDismissThreshold`), with optional **auto-dismiss after read time** so the toast is not easy to miss *or* leave blocking the sheet.
- **App Tour handoff** unchanged: no new unlock toast when Sprout feedback is suppressed at 1/1/1 before first tour.

**Out of scope (per issue)**

- Restoring the old hint card.
- Broad changes to linear section guidance unless required for toast timing.
- Changing growth-stage definitions or tutorial unlock rules (only presentation).

**Constraints and tradeoffs**

- Single Xcode target; keep logic **testable** via small pure helpers (timing, copy selection stays in strings / existing switches).
- **zh-Hans** must stay in parity with English for every touched `journal.guidance.*` key.
- `JournalScreen` is already large; prefer **small new types** or `AppTheme` durations over scattering magic numbers.

**Assumptions accepted** (confirm in PR if any should change)

- Auto-dismiss delays land in the **4–7 s** range for milestones and **~3.5–5 s** for generic bumps (readable on Dynamic Type default; adjust after device QA).
- A brief **delay (e.g. 0.12–0.2 s)** between header celebration start and toast entrance is acceptable to let haptics/subsidiary cues land first (no delay when `reduceMotion` is true).

**Open product question for human review**

- Should generic tier bumps use **shorter** copy than today (more “acknowledgment”) or **richer** copy (more “story”) now that the hint card is gone? The implementation plan proposes a *slightly* richer English line for Sprout and a clearer toward-Leaf line; alternative is minimal copy edits + timing-only.

---

## Michael Polanyi — how it shapes this fix

Polanyi distinguishes **tacit** knowing (what we integrate without saying) from **explicit** knowing (what we can articulate). In this UI:

| Polanyi idea | Design implication |
|--------------|--------------------|
| **Subsidiary vs focal awareness** | Header pulse, haptics, and pill state are **subsidiary**: users feel progress before reading. The toast should be **focal** text that *names* the shift, not a second tutorial panel. |
| **Tacit integration** | Veteran users already “know” the strip ladder. Generic rank-up toasts should stay **short**—enough to affirm, not to re-teach. |
| **Explicit articulation when structure is new** | First-time milestones (1/1/1, first Leaf, first Bloom) justified more **explicit** copy because the user is still integrating the practice into a coherent whole. |
| **Indwelling** | Wording should sound like encouragement **from inside the habit** (“you’re here now”) rather than external checklist pressure. |

This lens **rules out** replacing the removed hint card with a long toast. It **supports** tuned timing (auto-dismiss, optional stagger) so the body catches the cue first, then language catches up.

---

## Approaches considered

1. **Copy-only pass** — Lowest risk; fast to ship. Does not address “easy to miss” / persistent toast UX or a11y gap.
2. **Timing + motion + a11y (recommended)** — Add auto-dismiss from a single timing table, optional entrance delay vs header celebration, `accessibilityLabel`/`accessibilityAddTraits(.isModal)` or button label parity, keep scroll/tap dismiss. **Milestone vs generic** durations differ.
3. **Heavy refactor** — Extract full `JournalUnlockToastCoordinator` observable object. Better isolation but disproportionate to issue #225 unless `JournalScreen` edits become unmaintainable.

**Recommendation:** **Option 2**, implemented with a small `JournalUnlockToastTiming` (or `AppTheme` statics) + tests, minimal new surface area.

---

## Architecture (summary)

- **Presentation:** `JournalScreen.journalToastOverlay` + `presentUnlockToast` / `dismissUnlockToast*`.
- **Policy:** `JournalTodayOrientationPolicy` — no behavioral change expected; only verify suppression matrix after timing changes.
- **Strings:** `Localizable.xcstrings` keys already wired in `JournalUnlockToastView`.
- **Tests:** New unit tests for timing helper; existing `JournalTodayOrientationPolicyTests` stay green.

---

## Approval

This spec should be reviewed before code changes land. After approval, use the companion implementation plan: `docs/superpowers/plans/2026-04-09-issue-225-unlock-toast-polish.md`.
