# Agent memory (short form)

**Purpose:** Durable lessons, **explicit human decisions**, and **preferences** so future work does not regress. Not a changelog; not a scratchpad for full plans.

**Format:** One line per entry. Prefer `YYYY-MM-DD | scope: …` when the date matters. **Keep each line short** (aim ≤ ~200 characters). **Do not** paste long transcripts—distill to one claim.

**When to append:** The human states a correction, a non-obvious product choice, or “remember this.” After **merge-level** decisions, add **one** line if it would prevent a future agent from “fixing” the wrong thing.

**When *not* to append:** One-off task status, full PR bodies, or anything that belongs only in an issue/PR comment.

---

## Entries

- 2026-04-09 | UI: Sticky journal completion toolbar chip keeps **fixed expanded layout width** when icon-only; attempts to shrink width (or clip-to-reveal) caused jump or wrong-direction expansion. **Prefer stable feel over reclaiming literal toolbar space** (documented on PR #237).
