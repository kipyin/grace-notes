---
initiative_id: 003-issue-31-33-launch-toggle-performance
role: Architect
status: in_progress
updated_at: 2026-03-18
related_issue: 31,33,32

---

# Architecture

## Inputs Reviewed

- `[GraceNotes/docs/07-release-roadmap.md](../../07-release-roadmap.md)` (0.3.2 scope and acceptance intent)
- `[GraceNotes/docs/agent-log/initiatives/archive/003-issue-31-33-launch-toggle-performance/brief.md](./brief.md)`
- `[GraceNotes/docs/agent-log/initiatives/archive/004-issue-36-37-input-pipeline-stabilization/architecture.md](../004-issue-36-37-input-pipeline-stabilization/architecture.md)`
- `[GraceNotes/GraceNotes/Application/GraceNotesApp.swift](../../../GraceNotes/Application/GraceNotesApp.swift)`
- `[GraceNotes/GraceNotes/Data/Persistence/SwiftData/PersistenceController.swift](../../../GraceNotes/Data/Persistence/SwiftData/PersistenceController.swift)`
- `[GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift](../../../GraceNotes/Features/Settings/SettingsScreen.swift)`

## Decision

Keep `#31` and `#33` together under the `#32` umbrella because both are first-use trust problems, but structure delivery as two sequential slices so the first-launch fix can ship independently if reminder/settings work grows beyond the same cycle.

## Goals

- Show visible progress immediately on first launch instead of letting persistence setup read as a freeze.
- Use calm, personal loading copy centered on privacy and ownership, with light motion through a small rotating message set while startup work continues.
- Move reminder permission out of a raw toggle interaction and into a clearer settings-row drill-in flow with brief context before the system prompt.
- Make the reminder UI reflect actual granted or denied state so users can tell the difference between intent, failure, and success.
- Keep scope small enough for one delivery cycle without broad Settings or onboarding redesign.

## Non-Goals

- Do not expand this into general startup optimization beyond the first-launch path covered by `#31`.
- Do not redesign the overall Settings information architecture beyond the reminder row and its follow-on detail flow.
- Do not add new reminder product features beyond permission setup, status clarity, and existing time selection behavior.
- Do not treat `#32` as a standalone implementation target; keep it as umbrella tracking.

## Root Cause Analysis

### #31 — App frozen at first launch

`GraceNotesApp.init()` calls `PersistenceController.shared` synchronously on the main thread. That triggers `ModelContainer` creation (schema setup, CloudKit wiring, disk I/O), which blocks before any view appears.

### #33 — Most toggles lag on first tap

All four Settings toggles use `@AppStorage` bound to SwiftUI `Toggle`. Possible contributors:

- UserDefaults first-access cost
- Daily reminder `onChange` calls `ReminderScheduler.syncDailyReminder`, which may trigger `UNUserNotificationCenter.requestAuthorization()` on first enable
- Common "first use" overhead on main thread

### Relationship

Both likely stem from **synchronous main-thread work during first use** of a subsystem.

## Technical Scope

### Slice 1: First-launch startup responsiveness (`#31`)

1. Restructure app startup so the first rendered surface does not depend on synchronous `ModelContainer` creation.
2. Present a dedicated loading surface immediately on fresh startup while persistence is being prepared.
3. Start that surface with the approved base line, "We are setting up your private journal space...", and rotate through a small set of calm variants on a short cadence while setup remains in progress.
4. Progress the loading surface through three explicit states:
   - active loading
   - reassurance after a short timeout if setup is still running
   - retry-capable fallback if startup remains stalled or returns an error
5. Keep failure handling on the same startup surface. Do not leave the user on a blank screen, frozen shell, or partial main UI. A retry action should restart the startup attempt cleanly from the loading surface.

### Slice 2: Reminder settings trust and first-tap responsiveness (`#33`)

1. Replace the direct reminder toggle permission path with a tappable reminder settings row that opens a dedicated reminder configuration screen or drill-in view.
2. Use that drill-in surface to provide brief explanatory context before any system notification prompt is triggered.
3. Trigger `UNUserNotificationCenter` permission only from an explicit enable/continue action inside the drill-in flow, never from the raw list-row interaction itself.
4. Represent reminder state from actual permission and scheduling outcome rather than pending user intent. The summary state should remain legible from the main Settings screen and inside the drill-in view.
5. Preserve the existing reminder time configuration only after reminders are actually enabled, and clearly communicate when notifications are denied or unavailable.

## Affected Areas

- `GraceNotesApp.swift` — startup state ownership and conditional root rendering
- `PersistenceController.swift` — non-blocking startup boundary for persistence preparation
- First-launch loading view/state — copy rotation, reassurance, retry, and failure fallback
- `SettingsScreen.swift` — reminder row summary and navigation into drill-in flow
- Reminder configuration UI and scheduler integration — explicit permission request and final-state rendering

## Risks and Edge Cases

- Async startup must avoid duplicate container creation, repeated overlapping retries, or a state where onboarding/main content appears before persistence is ready.
- Timeout thresholds are a UX trust tool, not a strict performance promise. Values should be tuned conservatively so reassurance appears only when setup is genuinely lingering.
- Rotating copy should reassure without creating noise; keep the message set small and calm, and stop rotation as soon as startup completes or moves to a terminal fallback state.
- Reminder UI must roll back cleanly when permission is denied or scheduling fails. The screen should never show a reminder as enabled unless scheduling actually succeeded.
- Users who have already denied notifications at the system level need a clear "notifications off" state and guidance, not another control path that appears actionable but cannot succeed.
- Bundling remains sensible for release framing, but `#33` carries more interaction and QA surface than `#31`; keep the ship path for Slice 1 independent if needed.

## Sequencing

1. Implement Slice 1 startup restructuring and loading surface.
2. Validate first-launch behavior across normal, slow, and failed/stalled startup paths before moving on.
3. Implement Slice 2 reminder drill-in flow and migrate permission prompting out of the raw Settings toggle path.
4. Validate granted, denied, previously denied, disable, and reminder-time update states.
5. If Slice 2 expands, ship Slice 1 independently and keep `#33` as the remaining work inside this initiative umbrella.

## Close Criteria

- On fresh install, a visible loading screen appears immediately instead of a blank or frozen launch.
- The first-launch loading screen starts with privacy-centered copy and can rotate through a small calm message set while setup is in progress.
- If startup runs longer than expected, the UI shifts first to a reassurance state and then to a retry-capable fallback if recovery does not happen.
- If startup fails, the app stays on an explicit recovery surface with clear retry behavior rather than hanging or crashing into an unexplained state.
- Settings no longer request notification permission directly from a raw reminder toggle interaction.
- The reminder row opens a drill-in flow with brief explanatory context before the system permission prompt.
- After reminder setup completes, the UI clearly reflects the actual final state:
  - granted and scheduled shows reminders enabled with the selected time
  - denied or unavailable shows reminders off with guidance instead of implying success
- Existing journal, review, export, and non-reminder settings flows remain functional.
- Focused regression coverage or manual QA steps exist for startup retry/failure paths and reminder permission outcomes.

## Open Questions

- None. Exact timeout values and final copy variants can be tuned during implementation as long as they stay within the approved loading -> reassurance -> retry pattern.

## Next Owner

`Builder`, then `Test Lead`, to execute Slice 1 first, preserve the option to ship it independently, and then complete the reminder drill-in flow with validation across permission outcomes.