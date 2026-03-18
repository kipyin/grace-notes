---
initiative_id: issue-31-33-launch-toggle-performance
role: Test Lead
status: in_progress
updated_at: 2026-03-18
related_issue: 31,33,32
---

# Testing Handoff

## Decision

Slice 1 (`#31`) now uses a coordinator-driven startup flow that renders a startup surface immediately, performs persistence bootstrap off the main actor, transitions to reassurance when startup lingers, and offers retry only when persistence startup throws.

## Validation Checklist

- [x] Fresh launch shows startup UI immediately with visible progress copy.
- [x] Startup copy begins with "We are setting up your private journal space...".
- [x] Reassurance state appears when startup exceeds the reassurance threshold.
- [x] Retry UI appears only for thrown startup failures and starts a clean retry attempt.
- [x] Unit test mode still short-circuits app launch (`Color.clear`).
- [x] UI test mode remains deterministic (`-ui-testing` / `FIVECUBED_UI_TESTING`) and bypasses onboarding after startup readiness.
- [x] Focused coordinator tests pass (`StartupCoordinatorTests`, 5 tests).
- [x] `swiftlint lint` run completed (1 pre-existing warning in `JournalScreen.swift`, no new serious violations).

## Manual QA Steps

1. **Normal startup**
   - Install clean app build and launch.
   - Confirm startup surface appears immediately.
   - Confirm first line reads exactly: "We are setting up your private journal space...".
   - Confirm app transitions into onboarding (or main tabs if onboarding already completed) once persistence is ready.

2. **Slow startup path**
   - Use a delayed persistence factory in a debug/test harness (delay longer than reassurance threshold).
   - Launch app.
   - Confirm loading copy rotates and then enters reassurance state ("Still getting things ready...").
   - Confirm eventual success still transitions to onboarding/main without showing retry.

3. **Failure path**
   - Use a throwing persistence factory in debug/test harness.
   - Launch app.
   - Confirm startup surface remains visible and shows explicit retry affordance.
   - Confirm no blank screen, partial app shell, or crash.

4. **Retry recovery**
   - From failure state, switch factory to success and tap Retry once.
   - Confirm startup restarts from loading state.
   - Confirm repeated rapid retry taps do not create overlapping startup attempts.
   - Confirm successful transition to onboarding/main.

5. **Regression smoke (Slice 1 boundaries)**
   - Verify Today tab entry creation still works.
   - Verify Review tab opens and renders history.
   - Verify Share button remains available.
   - Verify Settings screen loads and non-reminder toggles remain functional.

## Next Owner

`Test Lead` for full simulator pass of manual startup paths, then `Release Manager` for Slice 1 ship decision independent of Slice 2.
