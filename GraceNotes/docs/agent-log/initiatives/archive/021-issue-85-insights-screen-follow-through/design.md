---
initiative_id: 021-issue-85-insights-screen-follow-through
role: Designer
status: completed
updated_at: 2026-03-24
related_issue: 85
related_pr: none
---

# Design

## Inputs Reviewed

- `brief.md`, GitHub [#85](https://github.com/kipyin/grace-notes/issues/85), `.impeccable.md` (calm, warm, supportive; clarity over novelty).
- Current `ReviewScreen` + `ReviewSummaryCard` (outer card + three inset panels, system segmented `Picker`).

## Decision

- **Thin-week follow-through:** When the user is in a **low-signal week** (operationalized in build as **fewer than four journal entries in the current review window**, or the card’s **pre-insight** empty message), show **one** calm primary control **Write today’s reflection** that switches to the **Today** tab (no new navigation stack).
- **Top rhythm:** Tighten **list row inset** above the insights card and **slightly reduce** internal padding between source, date range, and first panel so first content reads sooner without crowding.
- **Panel hierarchy:** **This week** uses **lead** title typography (body-scale serif semibold); **A pattern** (renamed from *A thread* for first-read clarity) and **A next step** use **supporting** title typography (meta-scale semibold). Secondary inset panels use **softer** fill and **lighter** stroke than the lead panel—**no** new border colors or accents on the outer card.
- **Mode control:** Keep the **system** segmented `Picker` (Insights / Timeline) via `ReviewModeSegmentedControl`; preserve `ReviewModePicker` accessibility id, selected trait, and hints—#85 hierarchy and thin-week work shipped without a custom segment control.
- **Microcopy:** English **A pattern** (catalog key unchanged: `String(localized: "A thread")` maps to displayed **A pattern**). Source chip **On your device** (was *On-device*). **zh-Hans:** section 2 title **规律** (short, parallel to “pattern”); source **仅在你的设备上** (trust + plain language).

## Rationale

Keeps nested-card calm while fixing scan order, discoverability, and the “what now?” gap in thin weeks without gamified urgency.

## Risks

System segmented control must preserve **VoiceOver** (selected trait, hints) and **identifier** `ReviewModePicker` for stability. Verify largest Dynamic Type sizes on device.

## Open Questions

- None blocking build; Strategist may later refine exact entry-count threshold (`< 4`) if analytics disagree.

## Next Owner

`Builder` / `Test Lead` — implementation complete in-repo; verify on device.
