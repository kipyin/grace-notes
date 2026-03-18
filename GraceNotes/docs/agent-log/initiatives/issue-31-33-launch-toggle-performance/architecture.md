## initiative_id: issue-31-33-launch-toggle-performance
role: Architect
status: in_progress
updated_at: 2026-03-18
related_issue: 31,33,32

---

# Architecture

## Inputs Reviewed

- `[GraceNotes/docs/07-release-roadmap.md](../../07-release-roadmap.md)` (0.3.2 scope and acceptance intent)
- `[GraceNotes/docs/agent-log/initiatives/issue-36-37-input-pipeline-stabilization/architecture.md](../issue-36-37-input-pipeline-stabilization/architecture.md)`
- `[GraceNotes/GraceNotes/Application/GraceNotesApp.swift](../../../GraceNotes/Application/GraceNotesApp.swift)`
- `[GraceNotes/GraceNotes/Data/Persistence/SwiftData/PersistenceController.swift](../../../GraceNotes/Data/Persistence/SwiftData/PersistenceController.swift)`
- `[GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift](../../../GraceNotes/Features/Settings/SettingsScreen.swift)`

## Decision

Scope initiative to #31 and #33 together. Defer ModelContainer creation off the main thread for #31; instrument and fix toggle lag for #33 based on findings.

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

### Phase 1: Defer ModelContainer creation (#31)

1. Add `PersistenceController.createAsync(cloudSyncEnabled:) async -> PersistenceController` that creates `ModelContainer` in `Task.detached`, then returns a controller initialized with that container.
2. Add internal init that accepts a pre-built `ModelContainer`.
3. In `GraceNotesApp`: avoid `PersistenceController.shared` in init; use `@State private var persistenceController: PersistenceController?` and `.task` to create asynchronously.
4. Show minimal loading/splash view until container is ready; then render `mainTabView` / `OnboardingScreen` with `.modelContainer(persistenceController!.container)`.

### Phase 2: Toggle lag (#33)

1. **Investigate:** Add `PerformanceTrace` around first `@AppStorage` write and `ReminderScheduler.syncDailyReminder`; reproduce on device.
2. **Fix (candidate):** UserDefaults warm-up, ensure reminder `onChange` is fully async, or optimistic toggle UI depending on findings.

## Affected Areas

- `PersistenceController.swift` — async factory, optional init
- `GraceNotesApp.swift` — loading state, async creation
- `SettingsScreen.swift` — Phase 2 instrumentation/fix

## Sequencing

1. Implement Phase 1 (#31); validate first launch feels responsive.
2. Instrument #33; reproduce and identify hotspot.
3. Apply Phase 2 fix based on findings.

## Close Criteria

- Fresh install: splash appears immediately; main content within 1–2 seconds. No perceptible freeze.
- Settings toggles: no noticeable lag on first tap.
- All existing flows (journal, history, share, reminders) work as before.
- Tests pass; update any that depend on `PersistenceController.shared` init timing.

## Open Questions

- None.

## Next Owner

`Implementer` to execute Phase 1, then instrument and fix Phase 2.