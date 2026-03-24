---
initiative_id: 019-repo-improvement-audit-roadmap
role: Architect
status: completed
updated_at: 2026-03-24
related_issue: 87
related_pr:
---

# Architecture

## Inputs Reviewed

- [brief.md](./brief.md)
- [SCHEMA.md](../../../SCHEMA.md)
- [2026-03-code-quality-analysis-plan.md](../../../../archive/2026-03-code-quality-analysis-plan.md)

## Decision

1. **Single inventory file:** [improvements-inventory.md](./improvements-inventory.md) is the canonical table. Each row includes: `id`, `area`, `finding`, `severity` (P0–P3), `pillar` (Aesthetic / Hygienic / Robust / Tests / Tooling / Product), `gh` (existing issue `#n` or `—`), `action` (link / new issue / absorbed), `proposed_milestone` (title string matching GitHub milestone), `chunk` (roadmap pack id).
2. **Issue convention:** **One GitHub issue per logical chunk** for net-new work (umbrella issues), with the inventory row linking to that issue. Existing issues are referenced, not recreated.
3. **Workflow:** `swiftlint lint` + targeted code reads → draft rows → `gh issue list --repo kipyin/grace-notes --state open --limit 200 --json number,title,labels,milestone` → merge/dedupe → edit `07-release-roadmap.md` → `gh issue create` with `--milestone` where titles exist.

**Executed:** Umbrella issues **#87**–**#90**; milestones created on GitHub; **#80**, **#83**–**#86** assigned to **0.5.2**.

## Rationale

A stable table format makes deduplication auditable; umbrella issues avoid dozens of micro-issues while keeping roadmap bullets traceable.

## Risks

Milestone titles must match GitHub exactly; mismatch fails `gh issue create --milestone`.

## Open Questions

- None.

## Next Owner

**None** — executed; see `qa.md` / `release.md`.
