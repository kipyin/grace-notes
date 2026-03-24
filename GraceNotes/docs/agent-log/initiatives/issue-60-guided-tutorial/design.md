---
initiative_id: issue-60-guided-tutorial
role: Designer
status: implemented
updated_at: 2026-03-21
related_issue: 60
---

# Design

## Decision

- **Hints**: Warm paper surface, meta/body typography (`AppTheme.warmPaperMetaEmphasis` + `warmPaperBody`), subordinate to the completion pill. Primary + “Got it” dismiss (plain text button, accent).
- **Copy**: Calm, warm, non-gamified (`.impeccable.md`). Hints short; toast first-time lines explicitly say “first Seed” / “first Harvest” without exclamation clutter.
- **Motion**: Reuse existing unlock toast timings; optional slightly longer read time for first-milestone toasts via `unlockToastVisibleSeconds`.
- **Today-only**: Hints hidden when viewing a past date (`JournalScreen(entryDate:)`).

## Open Questions

None.

## Next Owner

`QA Reviewer` — VoiceOver labels for hint + dismiss.
