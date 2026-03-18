---
initiative_id: issue-31-33-launch-toggle-performance
role: Strategist
status: in_progress
updated_at: 2026-03-18
related_issue: 31,33,32
---

# Brief

## Inputs Reviewed

- `GraceNotes/docs/07-release-roadmap.md` (0.3.2 scope: #31, #33)
- `GraceNotes/docs/agent-log/initiatives/issue-36-37-input-pipeline-stabilization/architecture.md` (staged #31/#33 as follow-up)
- `GraceNotes/docs/agent-log/initiatives/issue-31-33-launch-toggle-performance/architecture.md` (proposed technical approach)
- Release acceptance: "First launch and common settings interactions feel responsive"

## Problem

First launch currently feels frozen before the app earns trust, and settings toggles can hesitate on first tap. Both failures interrupt momentum at moments where the product should feel calm, reliable, and immediately understandable.

## User Value

Users should see the app respond right away on first open and should trust that settings changes happen when they tap them. This work protects first impression, reduces uncertainty, and keeps the journaling ritual from feeling fragile.

## Decision

Create a dedicated initiative to fix first-launch freeze (#31) and first-tap toggle lag (#33) as a single performance slice under the #32 umbrella.

## Scope In

- First-launch responsiveness for fresh install setup before the main app appears
- A clear interim loading experience while persistence is being prepared
- First-tap responsiveness for common settings toggles
- Reminder-toggle behavior that stays understandable if system permission is requested or denied

## Scope Out

- Broader performance work tracked under `#32` beyond first launch and settings
- New reminder feature design or broader Settings information architecture changes
- Non-performance polish unrelated to first impression or settings trust

## Priority Rationale

Both issues directly break first impression and core journaling momentum. The roadmap already treats them as release-blocking confidence work for `0.3.2`, and the architecture for `#36/#37` explicitly deferred them as follow-up. Bundling them is sensible as long as the team preserves the option to ship the first-launch fix independently if toggle investigation takes longer.

## Acceptance Intent

- On fresh install, the app shows immediate visible progress instead of appearing frozen.
- If startup work takes noticeable time, the screen explains that Grace Notes is preparing the user's private journal space in clear, personal language.
- If startup setup fails or stalls, the user is not left on an unexplained blank or stuck state.
- Settings toggles react immediately to touch and do not feel ignored on first use.
- Reminder-related toggles never leave the user unsure whether the setting actually changed.
- If notification permission is denied, the UI clearly reflects the final state and explains what to do next without implying success.

## Risks

- Async persistence setup may require app structure changes to support a trustworthy loading or recovery state.
- Toggle lag root cause still requires instrumentation before selecting the safest UX pattern.
- Optimistic toggle behavior is risky unless denial and rollback behavior are defined clearly.

## Recommended UX Direction

- First launch should use clear, personal loading copy centered on privacy and ownership. Preferred base line: "We are setting up your private journal space..."
- The loading screen can rotate through a small set of similarly calm messages every second or so to reassure the user that work is progressing without feeling noisy.
- If startup exceeds a short threshold, shift to a reassurance state such as "Still getting things ready..." and then offer a retry path if setup does not recover.
- Reminder permission should move out of direct toggle behavior into a settings-row drill-in flow with brief context before the system prompt.
- The reminder drill-in should make the final state explicit after permission is granted or denied so the user never mistakes intent for success.

## Open Questions

- None at the strategist level. Product direction is set; technical fit and exact copy variants should be finalized by `Architect` and `Implementer`.

## Next Owner

`Architect` to update technical scope and close criteria so they explicitly cover rotating first-launch copy, timeout-to-retry fallback behavior, and a settings-row drill-in reminder flow.
