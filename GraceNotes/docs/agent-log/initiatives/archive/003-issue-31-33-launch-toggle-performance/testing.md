---
initiative_id: 003-issue-31-33-launch-toggle-performance
role: Test Lead
status: in_progress
updated_at: 2026-03-18
related_issue: 31,33,32
---

# Testing Handoff

## Risk Map

- **Critical: First-launch trust path (`#31`)**
  - Startup surface must render immediately and never leave users on a blank/frozen frame.
  - Long-running startup must progress from loading to reassurance.
  - Throwing startup must stay recoverable and retry cleanly without overlapping attempts.
- **Critical: Reminder permission trust path (`#33`)**
  - Permission prompt must only happen from explicit action in drill-in flow.
  - Settings summary must reflect actual system status, not optimistic intent.
  - Denied state must provide clear recovery (`Open Settings`) and refresh on return.
- **Medium: Regression boundaries**
  - Startup restructuring must not break onboarding/main transition behavior.
  - Reminder flow changes must not regress non-reminder settings interactions.

## Test Strategy by Level

- **Unit**
  - `StartupCoordinatorTests` for startup state transitions, copy rotation, and retry protections.
  - `ReminderSchedulerTests` for authorization outcomes, request scheduling/removal, and disabled behavior.
  - `ReminderSettingsFlowModelTests` for drill-in flow state, enable/disable behavior, and implicit reschedule.
- **Integration / Build Validation**
  - `xcodebuild test` with focused `-only-testing` suites for `#31/#33` risk paths.
  - `swiftlint lint` from repo root to confirm style/quality baseline did not regress.
- **UI / Manual**
  - Explicit manual scenarios for first launch, delayed startup, startup failure/retry, enable/deny reminder flows, and return-from-settings refresh.

## Execution Results

- `swiftlint lint` (repo root): **pass**
  - 1 pre-existing warning remains in `JournalScreen.swift` (`file_length`, 405 lines).
  - No new serious violations.
- Focused simulator tests: **pass**
  - Initial command failed due unavailable destination (`iPhone 15` not installed locally).
  - Re-ran with available destination:
    - `xcodebuild -project GraceNotes/GraceNotes.xcodeproj -scheme GraceNotes -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:GraceNotesTests/StartupCoordinatorTests -only-testing:GraceNotesTests/ReminderSchedulerTests -only-testing:GraceNotesTests/ReminderSettingsFlowModelTests test`
  - Result: `** TEST SUCCEEDED **`
  - Focused test counts validated from output:
    - `StartupCoordinatorTests`: 6 passed
    - `ReminderSchedulerTests`: 11 passed
    - `ReminderSettingsFlowModelTests`: 9 passed
    - Total focused initiative tests: 26 passed

## Defects and Fixes

- **No new functional defects found** in automated initiative-targeted suites.
- **Execution environment issue (fixed during run):**
  - Requested simulator (`iPhone 15`) was unavailable.
  - Resolved by rerunning on installed simulator (`iPhone 17`, iOS 26.3.1).
- **Pre-existing technical debt observed (not introduced by this test pass):**
  - Swift 6 actor-isolation/data-race warnings in existing tests (`StartupCoordinatorTests`, `ReminderSchedulerTests` and related call sites).
  - Non-blocking today, but elevated future risk when strict concurrency enforcement is tightened.

## Coverage Adequacy Assessment

- **Automated coverage adequacy: Good for core initiative risks**
  - Critical startup and reminder state-machine behaviors are directly covered at unit level and pass.
  - Retry/overlap protections and denied-status behavior are explicitly exercised.
- **Manual coverage adequacy: Incomplete for release sign-off**
  - Runtime OS permission UX and settings round-trip behavior still require manual simulator/device validation.
  - Existing manual checklist remains the required final gate.

## Go/No-Go Testing Recommendation

- **Slice 1 (`#31`) engineering readiness:** **Go**
  - Automated risk coverage is strong and passing.
- **Combined `#31/#33` release readiness:** **Conditional Go**
  - Proceed if and only if manual permission-path QA below is completed and passes.
  - If manual denied/recovery flows cannot be verified this cycle, treat combined ship as **No-Go** and ship Slice 1 independently.

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

6. **Reminder first enable path**
   - Open Settings and tap Daily reminder row.
   - Confirm drill-in copy is concise and no system prompt appears on load.
   - Tap `Enable`.
   - Confirm system prompt appears only after explicit enable action.
   - Grant notifications and confirm drill-in enters enabled state with time controls visible.
   - Return to main Settings and confirm row summary shows selected reminder time.

7. **Denied and recovery path**
   - Deny notification permission when prompted (or pre-deny in iOS Settings).
   - Confirm drill-in shows denied guidance and `Open Settings`.
   - Tap `Open Settings`, allow notifications, then return to app.
   - Confirm drill-in and main Settings summary refresh automatically on app foreground and now show reminder state from live system status.

8. **Disable and reschedule path**
   - From enabled state, change reminder time in the wheel picker.
   - Confirm update saves implicitly (no explicit Save button) and appears in drill-in/main Settings summary.
   - Tap `Turn off`.
   - Confirm pending reminder request is removed and summary returns to Off state without prompting.

## Open Questions

- Can we schedule a dedicated manual permission-path pass on both a clean simulator state and at least one physical device before release freeze?
- Do we want to open a follow-up initiative to address Swift 6 concurrency warnings in test targets before language-mode tightening?

## Next Owner

`Test Lead` to complete the manual permission-path checklist, then `Release Manager` for final combined ship decision.
