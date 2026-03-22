---
initiative_id: release-0-5-1-patch
role: Release Manager
status: in_progress
updated_at: 2026-03-22
related_issue: none
related_pr: none
---

# Release 0.5.1 (patch)

## Inputs Reviewed

- `README.md`, `CHANGELOG.md`
- `GraceNotes/GraceNotes.xcodeproj/project.pbxproj`, shared `GraceNotes.xcscheme`
- Base: `release/0.5.0` aligned with `origin/release/0.5.0` at branch creation (`origin/main` remains behind that line)

## Decision

**Release readiness:** Branch and docs updated for **0.5.1**; **not** merge-ready until QA confirms the shared scheme Run=Release choice is intentional for the team.

## Open Questions

- Should `GraceNotes.xcscheme` Run action return to **Debug** for default development, keeping Release only for archive/CI?

## Next Owner

`QA Reviewer` — confirm packaging intent vs. developer ergonomics; run `make ci` on macOS before merge.
