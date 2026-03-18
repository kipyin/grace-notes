# Grace Notes Release Roadmap

Date: 2026-03-18

This roadmap turns the strategic priority stack into a release sequence grounded in the current open issue set.

## Roadmap principles

1. Fix the core journaling loop before adding more surface area.
2. Prioritize review value over browsing polish.
3. Treat trust and ownership as product, not back-office infrastructure.
4. Lower pressure without diluting the core reflection ritual.
5. Keep internal workflow improvements separate from user-facing releases.

## Release sequence

## 0.3.2 — Stabilization patch

**Goal:** Restore confidence in first launch and daily entry flow.

**Scope in**
- `#31` App frozen at first launch
- `#33` Most toggles lag when they are tapped the first time
- `#36` After entering an entry, the app freezes and keyboard disappears
- `#37` When entering an entry and hit `(+)` chip, the current input is discarded
- `#32` Overall app performance optimization, reframed as a tracking umbrella for follow-up work

**Why now**
- These issues directly break first impression and core journaling momentum.
- `#36` and `#37` are two symptoms of the same input pipeline problem.

**Acceptance intent**
- Input is never lost.
- Enter and `(+)` both preserve momentum.
- Keyboard stays available after commit.
- First launch and common settings interactions feel responsive.

## 0.4.0 — Insight quality

**Goal:** Make review feel specific, trustworthy, and grounded in the user’s own entries.

**Scope in**
- `#40` Review page is still generic even with AI Insights
- `#39` Fine tune AI prompts for chips
- `#11` Add a check mark after all 5 entries are complete within a section

**Why now**
- The strategy review identifies weak return on reflection as the biggest blocker.
- Better chip labeling improves the source material for review summaries.

**Acceptance intent**
- Review language references real recurring themes, people, and counts.
- AI output remains optional and falls back cleanly to deterministic insights.
- Completion feedback stays calm and legible inside the current ritual.

## 0.5.0 — Trust and ownership

**Goal:** Make Grace Notes feel safe to adopt as a real journal.

**Scope in**
- Structured import to complement existing export
- Simpler backup or sync confidence wins
- Clear privacy messaging for local versus cloud behavior
- `zh-Hant` localization if release capacity allows

**Why now**
- Users need confidence that their reflections are portable and recoverable.
- Export shipped in `0.2.3`, so import and clearer ownership are the natural next step.

**Acceptance intent**
- Users can restore from a prior export.
- Data ownership and privacy posture are easy to understand.

## 0.6.0 — Activation and flexible depth

**Goal:** Reduce pressure while preserving the structured reflection wedge.

**Scope in**
- Lighter success states for low-energy days
- Guided return and first-week support
- Quick versus full reflection modes
- Prompt packs or weekly reflection modes only if they deepen the ritual

**Why now**
- Some activation groundwork already shipped in `0.2.3`.
- This lane should build on a stable, useful, and trusted product.

**Acceptance intent**
- Users can keep the habit on lower-energy days.
- The app feels supportive rather than demanding.

## 0.6.x+ — Streak and calendar refinement

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
- `GraceNotes/docs/agent-log/initiatives/issue-41-agents-workflow/brief.md`
- `CHANGELOG.md`
