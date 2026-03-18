# Sprint Plan — Review Redesign + Onboarding & Lighter Completion

Date: 2026-03-17

## Sprint objective

Ship a clearer Review experience and first-week retention improvements without requiring Apple Developer verification dependencies.

## Scope

This sprint focuses on two tracks:

1. **Review cleanup and insight clarity**
2. **Onboarding + lighter completion logic**

## Sprint backlog (ready for implementation)

## Epic A — Review section clarity

### Story A1: Split Review into clear modes

**User story**
As a returning user, I want separate Insight and Timeline views so I can quickly understand my week before browsing old entries.

**Tasks**
- Add Review mode selector: `Insights` / `Timeline`.
- Keep weekly summary content in Insights mode.
- Keep existing month-grouped entry list in Timeline mode.

**Acceptance criteria**
- Review screen defaults to `Insights`.
- `Timeline` still allows navigation to past entries.
- UI remains visually consistent with Warm Paper theme.

### Story A2: Improve summary card readability

**User story**
As a user, I want weekly insights to be concise and scannable.

**Tasks**
- Add clear hierarchy: weekly narrative, recurring themes, resurfacing message, continuity prompt.
- Add source badge (`AI` vs `On-device`) for trust clarity.
- Add robust loading/empty states.

**Acceptance criteria**
- Weekly summary is readable without scrolling multiple screens.
- Source of insight is visible.
- Empty state gives meaningful guidance.

## Epic B — Activation and first-week retention

### Story B1: Add first-run onboarding flow

**User story**
As a new user, I want a short guided intro so the 5³ structure feels approachable.

**Tasks**
- Add onboarding shown on first launch only.
- Include three pages:
  - calm structure framing
  - review value over time
  - low-pressure success framing
- Add `Get Started` action to enter app.

**Acceptance criteria**
- Onboarding appears only before completion flag is set.
- Dismissing onboarding takes user to Today tab.
- Relaunch does not show onboarding again.

### Story B2: Implement lighter completion levels

**User story**
As a user on low-energy days, I want partial progress to count so I can maintain the habit.

**Tasks**
- Add completion tiers:
  - `none`
  - `quickCheckIn`
  - `standardReflection`
  - `fullFiveCubed`
- Keep existing full completion criteria unchanged for top tier.
- Expose current completion tier in UI (date header + history row status).

**Acceptance criteria**
- Any meaningful reflection produces at least `quickCheckIn`.
- Existing full completion behavior remains intact.
- UI displays completion tier labels clearly.

### Story B3: Review and completion integration

**User story**
As a user, I want Review timeline rows to reflect completion quality, not only binary complete/incomplete.

**Tasks**
- Use completion tier metadata in timeline rows.
- Show color-coded status chip text.

**Acceptance criteria**
- Rows show `Quick`, `Standard`, or `Full` where applicable.
- Visual style remains calm and not punitive.

## Testing checklist

### Automated tests
- Add model tests for completion tier rules.
- Add unit tests for onboarding state logic if extracted into helper.
- Keep existing review insight tests passing.

### Manual checks (macOS/Xcode)
- First launch shows onboarding; second launch skips.
- Journal entry UI updates completion level labels as content grows.
- Review mode toggle switches between Insight and Timeline.
- Timeline row status chips match entry completion tier.

### Linux validation in this environment
- Run `swiftlint lint` with no new serious violations.

## Definition of done

- Review screen is structurally cleaner and insight-first.
- First-run onboarding is live.
- Lighter completion logic is visible in UI and test-covered.
- No regression in existing journal editing, review navigation, or settings flows.
