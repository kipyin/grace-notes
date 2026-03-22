# Grace Notes Release Roadmap

Date: 2026-03-22

This roadmap turns the strategic priority stack into a release sequence grounded in the current open issue set. For **shipped** scope detail, treat `CHANGELOG.md` as the source of truth and keep this document aligned when tagging releases.

**GitHub milestones:** Open product issues on [kipyin/grace-notes](https://github.com/kipyin/grace-notes) use milestones that mirror the releases below: `0.5.0 - Insight quality and first-week guidance`, `0.6.0 - Trust and ownership`, `0.7.0 - Activation and flexible depth`, and `0.8.x+ - Streak and calendar refinement`. Internal workflow work (e.g. `#41`) stays off milestones. When you add or retarget issues, update this file and the milestone in the same change.

## Roadmap principles

1. Fix the core grace note loop before adding more surface area.
2. Prioritize review value over browsing polish.
3. Treat trust and ownership as product, not back-office infrastructure.
4. Lower pressure without diluting the core reflection ritual.
5. Keep internal workflow improvements separate from user-facing releases.
6. Resolve sync and persistence trust before deepening review intelligence.

## Release sequence

## 0.3.2 — Released (2026-03-18)

**Goal:** Restore confidence in first launch and daily entry flow.

**Release status**
- Shipped as `0.3.2` patch release.
- See `CHANGELOG.md` for final packaged scope details.

**Scope in**
- `#31` App frozen at first launch
- `#33` Most toggles lag when they are tapped the first time
- `#36` After entering an entry, the app freezes and keyboard disappears
- `#37` When entering an entry and hit `(+)` chip, the current input is discarded
- `#32` Overall app performance optimization, reframed as a tracking umbrella for follow-up work

**Why now**
- These issues directly break first impression and core grace note momentum.
- `#36` and `#37` are two symptoms of the same input pipeline problem.

**Acceptance intent**
- Input is never lost.
- Enter and `(+)` both preserve momentum.
- Keyboard stays available after commit.
- First launch and common settings interactions feel responsive.

## 0.3.3 — Released (2026-03-19)

**Goal:** Make the shipped experience feel calmer, clearer, and more intentionally finished across the app.

**Release status**
- Shipped as `0.3.3` patch release.
- See `CHANGELOG.md` for final packaged scope details.

**Scope in**
- Cross-app UI polish across onboarding or first-launch presentation, Today, Review, and Settings
- Small consistency improvements to spacing, hierarchy, copy, labels, and interaction feedback
- Loading, empty, success, and error states that currently feel abrupt, unclear, or visually rough
- Presentation refinements that strengthen trust and calmness without changing the underlying feature set

**Why now**
- `0.3.2` repaired the most visible reliability failures, but the app still needs a cohesion pass so those fixes feel truly shipped rather than merely stabilized.
- This patch size kept momentum without front-loading trust infrastructure (sync reliability) before controls and copy caught up.

**Acceptance intent**
- Primary surfaces feel visually and tonally consistent
- State changes are easy to understand and do not leave the user guessing what happened
- The release reads as polish and cohesion, not as a disguised feature expansion

## 0.3.4 — Released (2026-03-19)

**Goal:** Clarify completion meaning and strengthen user trust controls without expanding core surface area.

**Release status**
- Shipped as `0.3.4` patch release.
- See `CHANGELOG.md` for final packaged scope details.

**Scope in**
- Completion tier semantics and copy alignment (`In Progress` / `Seed` / `Harvest`)
- Inline completion status education in Today and consistent status chips in Review
- iCloud sync control and privacy copy hardening in Settings
- Targeted test-suite alignment for completion thresholds, summarization behavior, and reminder/UI assertions

**Why now**
- `0.3.3` improved overall polish, but completion semantics and trust controls still had avoidable ambiguity in day-to-day use.
- This patch added explicit iCloud preference and messaging; operational sync reliability is sequenced next in `0.4.0`.

**Acceptance intent**
- Users can understand what each completion level means without leaving the Today flow.
- Completion states are coherent across Today and Review.
- Data trust controls are explicit, understandable, and easy to verify.

## 0.3.5 — Released (2026-03-20)

**Goal:** Keep release packaging deterministic and metadata consistent.

**Release status**
- Shipped as `0.3.5` patch release.
- See `CHANGELOG.md` for final packaged scope details.

**Scope in**
- Font-copy build phase writes to the target build directory with explicit output paths for reliable app packaging
- Marketing version alignment for Grace Notes app configurations

**Why now**
- Small maintenance window before the next minor focus on sync trust.

**Acceptance intent**
- Release builds are repeatable; version labels match packaged artifacts.

## 0.4.0 — iCloud / SwiftData sync reliability

**Goal:** Make multi-device and cloud-backed storage feel dependable, legible, and recoverable—not only configurable.

**Release status**
- Shipped as `0.4.0` minor release (2026-03-21).
- See `CHANGELOG.md` for final packaged scope details.

**Scope in**
- User-visible sync health or last-known state where APIs and product tone allow (SwiftData + CloudKit)
- Behavior and Settings copy that match real outcomes, including failure and fallback paths (e.g. local store when CloudKit container creation fails)
- Clearer recovery semantics when toggling iCloud sync or when sync is unavailable
- Documented manual validation on signed builds and real devices (full CloudKit validation is not available in Linux CI; see `AGENTS.md`)

**Why now**
- Strategy review ranks trust—and a visible sync story—as the second-biggest product gap after review value.
- `0.3.4` shipped the sync toggle and privacy copy; users still need confidence that sync actually behaves.
- UAT (`08-uat-review-notes-release-0.3.3.md`) called out hardening storage and reliable iCloud sync.

**Acceptance intent**
- Users can infer whether their data is intended to be cloud-backed and what to do when something goes wrong.
- No silent mismatch between what Settings promises and what the persistence layer does.
- Multi-device checks are defined and repeatable for releases that touch persistence.

**Versioning note:** If marketing needs the `0.4.0` label for insight work instead, ship sync reliability as a patch (e.g. `0.3.6`) first, then proceed with insight as `0.4.0`; document that swap in this file when chosen.

## 0.5.0 — Insight quality and first-week guidance

Work tracked on branch `release/0.5.0`.

**Goal:** Make review feel specific, trustworthy, and grounded in the user’s own entries, while giving new and returning users calm first-week guidance that does not dilute the core ritual.

**Scope in**
- `#40` Review page is still generic even with AI Insights
- `#39` Fine tune AI prompts for chips
- `#11` Add a check mark after all 5 entries are complete within a section
- Guided return and first-week support (hints, coaching, or light onboarding tied to Seed/Harvest and the rhythm)—including `#60` first-run Today tutorial and related unlock feedback where shipped under this line
- `#67` Align journal completion logic (inProgress / seed / harvest / fullness)
- `#69` Skip cloud chip summarization when input fits chip unit budget (≤10 units)
- `#70` Commit chip TextField draft on focus loss (not only Return)
- `#71` Epic: Guided onboarding (behavior-first) + opt-in defaults (AI, reminders, iCloud)
- `#73` Onboarding: first journal path (Gratitude → Need → People)
- `#72` Onboarding: iCloud default off + migration notes
- `#74` Onboarding: Ripening → Harvest → Abundance guided flow
- `#75` Onboarding: suggest AI, reminders, iCloud after milestones

**Why now**
- The strategy review identifies weak return on reflection as the biggest blocker and calls for better first-week guidance.
- Better chip labeling improves the source material for review summaries.
- Activation for the first week does not need to wait on flexible-depth modes (`0.7.0`); it belongs alongside insight work in this release.
- This lane follows `0.4.0` so insight investment and guidance sit on firmer data-trust footing.

**Acceptance intent**
- Review language references real recurring themes, people, and counts.
- AI output remains optional and falls back cleanly to deterministic insights.
- Completion feedback stays calm and legible inside the current ritual.
- First-week and return flows feel supportive rather than demanding; users understand how to progress without extra pressure.

## 0.6.0 — Trust and ownership

**Goal:** Make Grace Notes feel safe to adopt as a real grace note practice.

**Scope in**
- Deeper **backup and ownership** UX beyond what shipped in `0.4.0` (JSON import/export is already available); e.g. clearer in-app guidance, edge cases, or portability story
- Clear privacy messaging for local versus cloud behavior (extends, does not replace, `0.4.0` sync truthfulness)
- `zh-Hant` localization if release capacity allows
- `#50` Add a show orientation again toggle in Settings

**Why now**
- Users need confidence that their reflections are portable and recoverable.
- Export shipped in `0.2.3` and structured import shipped in `0.4.0`; this lane focuses on trust copy and ownership clarity once review quality and first-week guidance (`0.5.0`) are stronger.

**Acceptance intent**
- Users can restore from a prior export.
- Data ownership and privacy posture are easy to understand.

## 0.7.0 — Activation and flexible depth

**Goal:** Reduce pressure through flexible depth and optional modes while preserving the structured reflection wedge. First-week and guided-return baseline ships in `0.5.0`; this release deepens how users can vary intensity over time.

**Scope in**
- Lighter success states for low-energy days
- Quick versus full reflection modes
- Prompt packs or weekly reflection modes only if they deepen the ritual

**Why now**
- Guided return and first-week support are sequenced in `0.5.0`.
- Some activation groundwork already shipped in `0.2.3`.
- This lane builds on a stable, useful, trusted product and the `0.5.0` activation baseline.

**Acceptance intent**
- Users can keep the habit on lower-energy days via lighter success states and clear quick paths.
- Optional depth (prompt packs, weekly reflection) strengthens the ritual without feeling noisy or mandatory.
- The app remains supportive rather than demanding as these options grow.

## 0.8.x+ — Streak and calendar refinement

**Goal:** Improve time-based review surfaces after the core value loop is stronger.

**Scope in**
- `#35` Reconsider how streaks should be presented
- Monthly calendar, if later user feedback still justifies it

**Why later**
- Calendar improves scanning, but it does not solve the primary retention gap.
- The exploration doc recommends deferring it unless demand or scope clearly supports it.

**Acceptance intent**
- Streaks are quieter and more supportive.
- Calendar, if built, is accessible and semantically clear.

## Out of product release scope

- `#41` Enhance agents workflow by incorporating `gh` commands

This is internal workflow enablement. Track it outside user-facing release packaging.

## Source documents

- `GraceNotes/docs/01-strategy-review.md`
- `GraceNotes/docs/03-review-insight-quality-contract.md`
- `GraceNotes/docs/04-review-insight-examples.md`
- `GraceNotes/docs/05-exploration-calendar-view.md`
- `GraceNotes/docs/06-tech-debt-backlog.md`
- `GraceNotes/docs/08-uat-review-notes-release-0.3.3.md` (storage / iCloud reliability signal)
- `GraceNotes/docs/09-uat-review-notes-release-0.3.4.md`
- `GraceNotes/docs/archive/2026-03-product-strategy-implementation.md` (iCloud foundation and runtime validation constraints)
- `GraceNotes/docs/agent-log/initiatives/issue-41-agents-workflow/brief.md`
- `CHANGELOG.md`
- GitHub milestones: https://github.com/kipyin/grace-notes/milestones
