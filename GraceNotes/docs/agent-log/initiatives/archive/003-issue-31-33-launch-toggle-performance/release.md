---
initiative_id: 003-issue-31-33-launch-toggle-performance
role: Release Manager
status: complete
updated_at: 2026-03-24
related_issue: 31,33,32
---

# Release Handoff

## Base and Version Check

- **Shipped:** **0.3.2** (see `CHANGELOG.md` and `07-release-roadmap.md` §0.3.2). Original integration used `release/0.3.2` (branch may no longer exist locally).
- **Version intent:** Startup, reminder trust, and input stability fixes under the **0.3.2** scope.

## Branch Plan

- Historical: work landed via **`release/0.3.2`**; no further release action on this initiative.

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

- **Decision:** **Shipped**; this file is a historical handoff. Use `testing.md` only if regressing startup or reminder flows.
- **Open Questions:** None for the **0.3.2** line.

## Next Owner

None.
