---
initiative_id: 020-issue-84-settings-section-headers
role: Architect
status: in_progress
updated_at: 2026-03-24
related_issue: 84
related_pr: none
---

# Architecture

## Inputs Reviewed

- `brief.md` (initiative 020).
- Issue #84 — scope: Settings `List` sections only; `.textCase(nil)` on header `Text`; include Import/Export screen.

## Decision

Implement presentation-only fix: add `.textCase(nil)` to every Settings-related `Section` header `Text` that does not already have it, so displayed text matches `Localizable.xcstrings` (e.g. “Cloud AI”, “Reminders”, “Data & Privacy”). No new `design.md` — Help section is the reference pattern.

## Rationale

SwiftUI `List` section headers default to an uppercase style; `.textCase(nil)` is the established in-app fix (Help). Same modifier on sibling headers is the smallest, consistent change.

## Risks

- Missing one header leaves a single all-caps outlier — caught by close criteria checklist and manual QA.

## Open Questions

- None.

## Next Owner

**Builder** — edit Swift only per **Affected files** below; run SwiftLint; on macOS run full test target.

### Goals

- All primary Settings tab section headers render in title/catalog case, not all caps.
- Import/Export sub-screen section headers behave the same.

### Non-Goals

- Changing non-Settings screens (e.g. Review).
- Redesigning typography tokens or header fonts.
- Reworking localization strings unless a string is wrong in the catalog (not required per issue).

### Affected files

- `GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift` — AI and Reminders headers (Help already has `.textCase(nil)`).
- `GraceNotes/GraceNotes/Features/Settings/DataPrivacySettingsSection.swift` — Data & Privacy header.
- `GraceNotes/GraceNotes/Features/Settings/ImportExportSettingsScreen.swift` — export and import section headers.

### Close criteria

1. Each `Section` header `Text` in the files above either has `.textCase(nil)` or an equivalent documented opt-out; none rely on default list header casing alone.
2. `swiftlint lint` passes for touched files.
3. `xcodebuild` test succeeds on macOS for the GraceNotes scheme.
4. Spot-check: English Settings shows “Cloud AI”, “Reminders”, “Data & Privacy”, “Help” without full-word all-caps styling.

### Sequencing

1. Swift changes in one commit or small PR.
2. Test Lead records commands + Go in `testing.md`.
3. QA + Release note user-visible polish and CHANGELOG if applicable.
