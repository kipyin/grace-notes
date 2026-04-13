# Agent memory (short form)

**Purpose:** Durable lessons, **explicit human decisions**, and **preferences** so future work does not regress. Not a changelog; not a scratchpad for full plans.

**Format:** One line per entry. Prefer `YYYY-MM-DD | scope: …` when the date matters. **Keep each line short** (aim ≤ ~200 characters). **Do not** paste long transcripts—distill to one claim.

**When to append:** The human states a correction, a non-obvious product choice, or “remember this.” After **merge-level** decisions, add **one** line if it would prevent a future agent from “fixing” the wrong thing.

**Proactive append (same session):** Agents should **not** wait for “update MEMORY.” If the thread had **reverts**, **≥2 wrong attempts** on the same axis, **frustration/repetition**, **restated constraints**, or an **explicit tradeoff**, distill **one** new line **before stopping**—see [`.agents/skills/memory/SKILL.md`](.agents/skills/memory/SKILL.md).

**When *not* to append:** One-off task status, full PR bodies, or anything that belongs only in an issue/PR comment.

---

## Entries

- 2026-04-12 | **Sentry:** `parse_fix_response` must treat `NO_CHANGE` as valid when Cursor prints prose, markdown, or a standalone line—not only when the entire output starts with `NO_CHANGE`; when multiple fenced blocks exist, prefer the swift-fenced block.
- 2026-04-10 | **GitHub text /gh:** Never add tool-attribution footers to issues or PRs. If a client auto-appends lines like “Made with Cursor”, remove them via `gh pr edit` so descriptions match repo rules.
- 2026-04-10 | **Scope:** “Writing-plans” means produce the plan artifact first; **do not** implement and open a full code PR unless the user clearly asked to execute the plan in the same request (confirm when both appear).
- 2026-04-10 | **Environment:** Treat **`user_info` OS as authoritative** (e.g. `darwin` ⇒ macOS, Xcode/iOS SDK may be available). **AGENTS.md** “Linux VM cannot compile SwiftUI” is for Cursor Cloud defaults, not a reason to skip `grace ci` when the session is on macOS.
- 2026-04-10 | **Verification handoff:** When OS is **darwin** and Swift/app code changed, **run `grace ci` (or `grace test`) before claiming verification**—do not tell the human CI “wasn’t run here / needs macOS.”
- 2026-04-09 | UI: Sticky journal completion toolbar chip keeps **fixed expanded layout width** when icon-only; attempts to shrink width (or clip-to-reveal) caused jump or wrong-direction expansion. **Prefer stable feel over reclaiming literal toolbar space** (documented on PR #237).
