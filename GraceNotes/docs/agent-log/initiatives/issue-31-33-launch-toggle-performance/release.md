---
initiative_id: issue-31-33-launch-toggle-performance
role: Release Manager
status: in_progress
updated_at: 2026-03-18
related_issue: 31,33,32
---

# Release Handoff

## Base and Version Check

- **Target release branch:** `release/0.3.2`
- **Branch state:** branch exists and is active; worktree contains in-progress Slice 2 files plus tests/docs.
- **Version intent:** package current startup/reminder/input trust fixes under `0.3.2` scope already mapped in roadmap.

## Branch Plan

- Keep implementation on the existing `release/0.3.2` branch.
- Land the remaining uncommitted reminder Slice 2 changes before packaging docs-only finalization.
- Avoid mixing unrelated cleanup into this release branch.

## Commit Plan and Message

- **Chunk 1 - Reminder scheduling contract and status truth**
  - Files: `ReminderScheduler.swift`, `ReminderSettings.swift`, `ReminderSchedulerTests.swift`
  - Intent: derive reminder status from live system state and split explicit permission path from passive reads.
  - Suggested commit subject: `feat: derive reminder state from live notification status`
  - Suggested body footer:
    - `Closes #33`

- **Chunk 2 - Settings drill-in reminder UX**
  - Files: `SettingsScreen.swift`, `ReminderSettingsFlowModel.swift`, `ReminderSettingsDetailScreen.swift`, `Localizable.xcstrings`, `ReminderSettingsFlowModelTests.swift`
  - Intent: replace inline toggle with explicit drill-in flow and denied/off/error handling.
  - Suggested commit subject: `feat: move reminder setup to explicit settings drill-in`
  - Suggested body footer:
    - `Closes #33`

- **Chunk 3 - Validation and release documentation**
  - Files: `testing.md`, `README.md`, `CHANGELOG.md`, `release.md`
  - Intent: capture verification evidence and align release-facing docs with shipped behavior.
  - Suggested commit subject: `docs: align 0.3.2 notes with startup and reminder fixes`
  - Suggested body footer:
    - `Closes #31`
    - `Closes #36`
    - `Closes #37`

## PR Title and Description

- **PR title**
  - `release: ship 0.3.2 startup, reminder trust, and input stability fixes`

- **PR description**
  - `## Summary`
  - `- Improves first-launch trust with an immediate startup loading/recovery surface.`
  - `- Replaces inline reminder toggle prompting with a dedicated explicit-permission reminder flow.`
  - `- Stabilizes entry/chip input behavior so text and keyboard momentum are preserved.`
  - ``
  - `## Test plan`
  - `- [x] swiftlint lint`
  - `- [x] Focused tests: ReminderSchedulerTests, ReminderSettingsFlowModelTests`
  - `- [ ] Manual QA pass for denied->Settings->return reminder recovery`
  - `- [ ] Manual first-launch slow/failure retry scenarios`

## Documentation Check

- `README.md` updated: `0.3.2` "What's new" now reflects shipped startup/reminder/input behavior.
- `CHANGELOG.md` updated: `0.3.2` entries now describe feature/fix scope instead of metadata-only framing.
- Initiative docs reviewed: `architecture.md`, `testing.md`.
- `qa.md` is not present for this initiative; manual QA checklist remains tracked in `testing.md`.

## Merge/Release Readiness

- **Decision:** Conditional Go for combined scope.
- **Blocking checks before final release tag:** complete manual permission-path and startup retry/failure checklist items in `testing.md`.
- **Risk posture:** automated coverage is strong; remaining risk is OS-level/manual reminder permission path validation.

## Open Questions

- Should final release sign-off require one physical-device permission-path pass in addition to simulator coverage?
- Do we split Slice 1-only fallback packaging if manual reminder-path QA is not completed before freeze?

## Next Owner

`QA Reviewer` for final manual validation sign-off, then `Release Manager` for final publish decision.
