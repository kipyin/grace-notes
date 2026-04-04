# Growth drill-down: match Section mix (toolbar subtitle) — design

**Status:** Approved direction — Option 1 (toolbar identity + subtitle criterion)  
**Related product area:** Past → Review history → Growth stage drill-down sheet  
**Companion theme:** Align Growth drill-down with Section mix “calendar-first” feel while keeping stage explanation visible.

> **Repo note:** This spec is under `docs/product/` so it can be committed; `docs/superpowers/` is gitignored (agent-local plans).

---

## Problem (plain language)

The **Growth stage** detail sheet currently reads like a small **report** above the calendar: a “Summary” label, a block of explanation, and another section-style heading before you get to the calendar. The **Section mix** sheets feel lighter: **title in the top bar**, then **mostly calendar**.

People still need the **explanation of what the stage means**, but it should not feel like a **different kind of screen** or push the calendar too far down.

## Goals

- **G1 — Same vibe as Section mix:** When there are days to show, the main content should be **the calendar**, not a reading passage first.
- **G2 — Keep growth context:** Users still see **which stage** they opened (icon + name) and **what it means** (criterion text), without digging through a separate pattern.
- **G3 — Respect accessibility:** Screen readers should get **one clear announcement** for the top area (stage + explanation), not a confusing sequence of fake “sections.”

## Non-goals

- Changing **how** days are matched, colored, or scrolled in the calendar grid.
- Redesigning the **Section mix** drill-downs (they stay the reference pattern).
- Adding a **second modal** or “learn more” flow (Option 3) unless we reopen scope later.

## User-visible design (Option 1)

### Top of the sheet (navigation bar)

- **First line:** Same as today — **small skyline picture** + **stage name** (e.g. “Balanced”).
- **Second line (new home for the explanation):** The **criterion sentence** (what this stage means) appears **directly under the title**, still in the top bar area, in **smaller, softer text**, centered under the first line.

This replaces the old **“Summary” block** and extra heading **above** the calendar.

### Middle of the sheet (body)

- **When there are matching days:** The screen should look like Section mix: **calendar first** — no “Summary” label, no duplicate headings in the body.
- **When there are no matching days:** Show the friendly **empty state** (calendar illustration + short message). **Do not** repeat the old stacked “Summary” sections above it; the explanation already lives in the **top bar subtitle**.

### Edge cases we care about

- **Large text sizes:** The subtitle may need to **wrap a little** or **shrink slightly** so the title stays readable, but must not explode into a huge block that steals the whole screen. If needed, **limit to two lines** in the bar cluster and rely on **VoiceOver** (which can read the full string) and **dynamic type** behavior that stays reasonable on small phones.
- **Very small phones:** Prefer **keeping two lines** for the criterion in the bar rather than putting it back in the body; if engineering hits a hard limit, we revisit together (not assumed in v1).

## Engineering notes (high level, for implementers)

- **Where:** `GrowthStageDrilldownSheet` in `ReviewHistoryDrilldownSheets.swift` — restructure toolbar `.principal` into a **vertical stack** (title row + criterion text); remove or bypass **`growthSummarySections`** for the **non-empty** path so **`above`** in `ReviewHistoryDrilldownPeekContainer` matches Section mix (empty / zero-height).
- **Empty path:** Drop body **Summary** / dates heading duplication; keep **ContentUnavailableView** only, with criterion in toolbar subtitle.
- **Accessibility:** Principal stack — combine for VoiceOver so the stage + explanation read as **one** focused element.
- **Tests / checks:** Manual QA on **iPhone SE–class** and **large Dynamic Type**; optional snapshot or UI coverage if the project already uses them for Past flows.

## Self-review (spec quality)

- **Placeholders:** None — direction is specific enough to implement.
- **Consistency:** Aligns with Section mix calendar-first body; explanation stays visible via toolbar subtitle.
- **Scope:** Single sheet pattern change; no cross-feature refactor.
- **Ambiguity:** Any future change to “truncate vs third line” is explicitly “revisit if engineering hits a hard limit,” not required for acceptance.

---

## Acceptance checklist (for QA)

- [ ] Growth drill-down **with** matches: calendar appears **without** a “Summary” section or duplicate headings in the body; criterion is visible **under** the stage title in the top area.
- [ ] Growth drill-down **without** matches: empty state only; criterion still visible in the top area.
- [ ] Section mix drill-downs: **unchanged** in structure (still title + calendar-first).
- [ ] VoiceOver: top of sheet reads as **coherent** stage + explanation.
