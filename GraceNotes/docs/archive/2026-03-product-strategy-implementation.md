# Product Strategy Implementation Plan — 2026-03-17

This document translates the strategy review into an execution roadmap with immediate implementation scope, architecture choices, and rollout checkpoints.

Source strategy review: `PRODUCT_STRATEGY_REVIEW_2026-03-17.md`

## Strategic focus

The strategy review identifies the core blocker: users invest effort in reflection, but the app returns limited compounding value.

This implementation plan focuses on two high-leverage tracks:

1. **Return on reflection** via Review insights (deterministic + AI).
2. **Trust and ownership** via iCloud sync architecture and backup/export.

## Product intent

Grace Notes should be positioned and built as a **guided reflection journal**, not a broad mindfulness platform.

The implementation should strengthen:

- calm, structured reflection
- continuity over time
- confidence in data ownership and safety

## Delivery lanes

## Lane A — Review loop (Now)

### Goal

Make past writing actively useful.

### Deliverables

- Evolve user-facing History into **Review**
- Weekly summary card above chronological list
- Recurring themes:
  - gratitudes
  - needs
  - people in mind
- Continuity prompt to guide next reflection

### Architecture

- Add a typed review insights model (`ReviewInsights`)
- Add deterministic local insights generator (frequency and recency)
- Add AI insights generator for richer weekly narrative
- Use provider fallback:
  - AI result when available and enabled
  - deterministic result otherwise

### Success indicators

- Review tab usage increases relative to baseline history-only browsing
- More users revisit prior entries in week 1
- Users report better pattern awareness

## Lane B — Trust and ownership (Now)

### Goal

Make the app trustworthy for primary journaling.

### Deliverables

- iCloud/CloudKit sync architecture foundation
- Settings messaging that explains local/cloud behavior clearly
- Structured versioned JSON export as backup and ownership pathway

### Architecture

- CloudKit-capable SwiftData container configuration
- iCloud entitlements + project capability wiring
- Export service that serializes full journal archive:
  - schema version
  - export timestamp
  - full entry payloads for future import compatibility

### Success indicators

- Users have visible sync/backup story in app
- Support anxiety around data loss decreases
- Export is usable as durable migration/backup artifact

## Lane C — Activation and habit design (Next)

### Goal

Reduce intimidation and improve first-week retention.

### Next deliverables

- guided onboarding for 5-5-5 ritual
- lighter completion paths for low-energy days
- first-week coaching prompts
- reminder voice and recovery messaging improvements

## Lane D — Flexible reflection depth (Later)

### Goal

Broaden usefulness without diluting the core ritual.

### Later deliverables

- quick/full reflection modes
- themed prompt packs
- richer monthly review artifacts

## Immediate implementation scope in this cycle

### Included

- strategy-to-execution artifact (this doc)
- Review tab evolution with weekly insights
- advanced AI review insight generation with safe fallback
- iCloud sync architecture wiring and settings messaging
- JSON export backup flow in Settings

### Deferred

- import UI and restore flows
- conflict-resolution UX for multi-device edits
- advanced onboarding redesign
- additional reflection modes

## Technical constraints and validation notes

- Linux cloud environment cannot run iOS simulator/Xcode tests.
- Runtime validation for CloudKit sync requires macOS + signed iCloud environment.
- This cycle should include deterministic unit tests for new logic, plus lint and static verification in Linux.

## Rollout and risk controls

### AI insights

- Keep AI insights opt-in
- Explain cloud transmission clearly
- Require typed decode path
- Always provide deterministic fallback

### iCloud sync

- Keep a clear local fallback and explicit backup export
- Document expected sync behavior in settings copy
- Validate capability setup and multi-device sync on macOS before release

## Definition of done for this strategy slice

1. Review experience surfaces weekly insights with fallback behavior.
2. Users can enable AI insights and understand privacy implications.
3. Project includes iCloud sync architecture foundation.
4. Users can export full journal archive as versioned JSON.
5. Code includes targeted tests and lint remains in acceptable range.
