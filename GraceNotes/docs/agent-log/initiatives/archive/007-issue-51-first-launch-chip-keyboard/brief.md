---
initiative_id: 007-issue-51-first-launch-chip-keyboard
role: Strategist
status: draft
updated_at: 2026-03-18
related_issue: 51
---

# Brief

## Inputs Reviewed

- GitHub issue `#51`: "Upon first launch, after clicking on an existing chip, it takes ~4-5 seconds for the keyboard to show up."
- `GraceNotes/docs/07-release-roadmap.md` (0.3.2 shipped #31, #33, #36, #37; #51 not yet in roadmap)
- `GraceNotes/docs/agent-log/initiatives/archive/003-issue-31-33-launch-toggle-performance/brief.md` (first-launch and toggle performance)
- `GraceNotes/docs/agent-log/initiatives/archive/004-issue-36-37-input-pipeline-stabilization/architecture.md` (keyboard/focus lifecycle, chip tap flow)
- Chip tap → `performChipTap` → `restoreInputFocus` flow in `JournalScreenChipHandling` and `JournalScreen`

## Problem

On first launch, when a user taps an existing chip to edit it, the keyboard takes 4–5 seconds to appear. The app appears unresponsive during that window, breaking the expectation that tapping to edit should feel immediate. This occurs specifically on first use—a cold-start interaction—and targets a high-value path: returning users opening an entry and jumping directly into editing.

## User Value

Users should be able to tap an existing chip and start typing without perceptible delay. The 4–5 second lag signals that something is wrong, undermines trust in the app’s responsiveness, and interrupts the journaling ritual at a moment when the user expects to write.

## Decision

Create a dedicated initiative to fix first-launch keyboard lag when tapping an existing chip, scoped to the tap-to-edit flow on cold start.

## Scope In

- First-launch, first-chip-tap path where keyboard takes 4–5 seconds to appear
- Cold-start factors that affect keyboard/focus readiness: persistence warmup, framework initialization, main-thread blocking in the chip-tap → focus path
- User-visible outcome: keyboard appears within a reasonable time (target: sub-second) when tapping an existing chip on first launch

## Scope Out

- General keyboard performance on warm starts (already-visited sessions)
- First-launch freeze before the main screen appears (#31)
- First-tap toggle lag in settings (#33)
- Keyboard disappearance or input loss after commit (#36, #37)
- Broader performance tuning unrelated to this specific tap-to-edit cold path

## Priority Rationale

First impression matters. The 0.3.2 release addressed first-launch freeze and input pipeline stability; #51 is a remaining first-launch performance hole. Users who open an existing entry and tap a chip experience the same “app is broken” feeling that #31 and #36 targeted. Fixing it closes a gap in the “app feels responsive on first use” story and supports the roadmap’s focus on trust and momentum.

## Acceptance Intent

- On fresh install or first launch, tapping an existing chip (gratitude, need, or person) results in the keyboard appearing within a tolerable delay (target: under 1 second).
- The app does not appear frozen during that period; some visible feedback (e.g., focus highlight) should indicate that the tap was recognized.
- Behavior on subsequent launches and warm sessions remains stable and responsive.

## Risks

- Root cause may be system-level (keyboard subsystem cold load) rather than app-level, limiting mitigation options.
- Overlap with #31 cold-start work; fixes may share infrastructure (e.g., deferred initialization, loading UX).

## Open Questions

- Does the lag occur for all chip sections equally, or only when certain data or frameworks are first accessed?
- Is the delay primarily keyboard appearance, or does it include chip content loading and focus assignment?
- Should this be bundled with 0.4.0 (insight quality) or treated as a 0.3.x patch alongside remaining performance work?

## Next Owner

`Architect` to define technical scope, instrumentation approach for root-cause analysis, and close criteria (including measurable latency targets).
