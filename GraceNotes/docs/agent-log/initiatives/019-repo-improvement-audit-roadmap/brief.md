---
initiative_id: 019-repo-improvement-audit-roadmap
role: Strategist
status: in_progress
updated_at: 2026-03-24
related_issue:
related_pr:
---

# Brief

## Inputs Reviewed

- [AGENTS.md](../../../../../AGENTS.md) (code style, boundaries, test expectations)
- [2026-03-code-quality-analysis-plan.md](../../../archive/2026-03-code-quality-analysis-plan.md)
- [07-release-roadmap.md](../../../07-release-roadmap.md)
- Open GitHub issues on `kipyin/grace-notes` (reconciled in `improvements-inventory.md`)

## Decision

Deliver a **repo-wide improvement inventory** (architecture, style, bugs, tests, features, tooling), **deduplicated against GitHub**, grouped into **release-shaped chunks**, reflected in **`07-release-roadmap.md`**, with **new tracking issues** created and assigned to **semantic release milestones** (including internal/tech work mapped to the nearest version).

## Rationale

The product already uses a versioned roadmap and milestones; a one-time structured audit prevents duplicate issues, surfaces gaps tests and SwiftLint do not catch alone, and makes patch vs minor boundaries explicit.

## Risks

- Scope explosion: mitigate with severity and “parking lot” rows in the inventory.
- Audit staleness: inventory header records date and SwiftLint snapshot.
- Linux environment cannot run `xcodebuild`; compile/test proof remains macOS-owned per issue acceptance.

## Open Questions

- None.

## Next Owner

**Architect** — confirm inventory schema and `gh` workflow in `architecture.md` (done in this initiative). **Builder / agent** executes audit, roadmap edit, and `gh issue create` per `architecture.md`.
