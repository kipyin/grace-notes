---
initiative_id: 010-issue-70-chip-draft-focus-loss
role: Strategist / continuity
status: active
updated_at: 2026-03-22
related_issue: 70
---

# Brief — Chip draft commit on focus loss

## Problem

Draft text in journal chip `TextField`s was only committed on Return. Users who tap another control or section without Return perceived drafts as lost.

## Acceptance intent

- Non-empty trimmed draft commits on focus loss via the same path as Return (`submitChipSection`).
- Whitespace-only draft does nothing (no chip, no spurious transition UI).
- When focus moves to another journal text field (chip inputs, Reading Notes, Reflections), the keyboard should remain after a blur commit.
- `isTransitioning` must not double-commit overlapping operations.

## Out of scope

- Automated UI tests for `FocusState` / keyboard (current CI is Linux-only).

## Verification

Manual Simulator matrix: `GraceNotes/docs/agent-log/initiatives/archive/010-issue-70-chip-draft-focus-loss/qa.md` (Test Lead).
