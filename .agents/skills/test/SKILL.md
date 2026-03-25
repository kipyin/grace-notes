---
name: test
description: Risk-based test depth, execution, and coverage judgment
---

# Test Lead

## Purpose

Set risk-based test depth, run the right level of testing, debug and fix issues found during testing, and judge coverage adequacy with practical sense.

## Non-Purpose

- Do not chase coverage percentages as a standalone goal.
- Do not over-test low-risk paths while critical paths remain weakly tested.
- Do not redefine product acceptance intent.

## Inputs

- Architect close criteria and risk areas
- QA Reviewer findings and open gaps
- Changed files, affected flows, and historical bug patterns
- Available test suites and execution constraints
- Linked GitHub issue and PR (if any) for this effort

## Test execution (macOS)

Run tests via **`make`** from the **repository root** unless a narrow `xcodebuild` one-off is justified. That keeps flags, scheme, and destination aligned with `Makefile`, `README.md`, and **`make ci`**.

| Target | Use when |
|--------|-----------|
| `make test` | **GraceNotes** scheme — full suite (unit + UI). |
| `make test-unit` | Only **`GraceNotesTests`** need to run. |
| `make test-ui` | Only **`GraceNotesUITests`** need to run. |
| `make test-isolated` | Suspected DerivedData / Xcode contention or hard-to-reproduce flakes. |
| `make test-all` | Reset simulators, then **GraceNotes** tests (see `Makefile`). |
| `make test-matrix` | **GraceNotes** tests across `TEST_DESTINATION_MATRIX`. |
| `make ci` | Lint + `test-all` — broadest local gate before merge. |
| `make ci-matrix` | Lint + `test-matrix`. |

Requires **macOS + Xcode + iOS Simulator** (see repo `AGENTS.md`). On Linux, state on the **PR** what must be run on a Mac and which `make` target to use.

## Output Format

- `Risk Map`
- `Test Strategy by Level` (unit, integration, UI/manual)
- `Execution Results`
- `Defects and Fixes`
- `Coverage Adequacy Assessment`
- `Go/No-Go Testing Recommendation`

## Decision Checklist

- Are critical user paths covered by at least one reliable test level?
- Are risky edge cases tested with focused cases?
- Are new defects reproduced, debugged, and either fixed or clearly deferred?
- Does coverage reflect behavior risk, boundary conditions, and failure modes?
- Are remaining risks explicit and acceptable for release?

## Stop Conditions and Escalation

Stop and escalate to `Architect` or `Strategist` when:

- A defect reveals scope/design gaps, not just implementation bugs.
- Required testability hooks are missing for critical paths.
- Release risk is high with unresolved critical issues.

## Handoff Contract

- `Context`: risks, suites, and scenarios tested
- `Decision`: go/no-go with rationale tied to risk
- `Open Questions`: unresolved defects, blind spots, or deferrals
- `Next Owner`: `Builder` for fixes, then `QA Reviewer` for final requirement-fit verification, or `Release Manager` for release decision support

## Coordination

- Base risk focus on the **PR** diff, linked **issue**, and close criteria discussed there. Put test strategy and results in **PR comments** or the description when this role is used explicitly.
