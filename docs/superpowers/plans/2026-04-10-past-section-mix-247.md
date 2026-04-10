# Past Section mix strip & legend (#247) Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On Past → Section mix, show integer **%** in the proportional bar, keep legend counts (not %), and style the legend like Most Recurring / Trending (meta label + `ReviewCountBadge` with per-section accent).

**Architecture:** Extend `ReviewSectionDistributionStripLayout` with a small pure function for display percents (integer round; all-zero totals → `[0,0,0]`). Update `ReviewHistorySectionStrip` in `ReviewHistoryInsightsPanels.swift` for bar labels, legend row layout, and richer accessibility strings. Add localized format keys for `%` text and VoiceOver.

**Tech stack:** SwiftUI, SwiftData app target only; `Localizable.xcstrings`; `GraceNotesTests` unit tests.

---

### Task 1: Percent math (tested)

**Files:**
- Modify: `GraceNotes/GraceNotes/Features/Journal/Views/ReviewHistoryInsightsPanels.swift` (`ReviewSectionDistributionStripLayout`)
- Modify: `GraceNotesTests/Features/Journal/SectionDistributionStripLayoutTests.swift`

- [x] **Step 1:** Add `integerDisplayPercents(gratitudeMentions:needMentions:peopleMentions:) -> [Int]` next to `segmentWidths`, same argument order. If `total == 0`, return `[0, 0, 0]`. Otherwise `Int((Double(c) / Double(total) * 100).rounded())` per segment.
- [x] **Step 2:** Add tests: all-zero → `[0,0,0]`; e.g. `6,5,5` → `[38, 31, 31]` or whatever rounding yields; smoke check length 3.
- [x] **Step 3:** `swiftlint lint` on touched Swift files.

### Task 2: UI + palette + strings

**Files:**
- Modify: `ReviewHistoryInsightsPanels.swift` (`ReviewSectionDistributionPalette`, `ReviewHistorySectionStrip`)
- Modify: `GraceNotes/GraceNotes/Localizable.xcstrings`

- [x] **Step 1:** Add `countBadgeAccent(for: ReviewStatsSectionKind) -> Color` on `ReviewSectionDistributionPalette` (reuse the same family as `border` / section chrome—full-opacity border colors are fine).
- [x] **Step 2:** In the strip `HStack`, compute `let percents = ReviewSectionDistributionStripLayout.integerDisplayPercents(...)` once; replace bar `Text` with localized `"\(pct)%"` via new key `review.sectionMix.segmentPercent` (`%lld%%`, en + zh-Hans).
- [x] **Step 3:** Legend rows: `HStack(alignment: .center, spacing: 10)`; section title `AppTheme.warmPaperMeta`; trailing `ReviewCountBadge(value: item.count.formatted(), accent: ReviewSectionDistributionPalette.countBadgeAccent(for: item.kind))`.
- [x] **Step 4:** Accessibility: new format key including section name, mention count, and display percent for strip buttons and legend rows (hints unchanged). Empty-total case still sensible (`0` mentions, `0` percent).

### Task 3: Ship

**Files:**
- Modify: `CHANGELOG.md` (Unreleased user-facing line if warranted)

- [x] **Step 1:** Branch `feat/past-section-mix-247` from `main`, commit focused message, push.
- [x] **Step 2:** Open PR with `Closes #247`, labels `feat`, `past`, `p3` (omit `full-ci` unless requested). Verification: `swiftlint lint`; on macOS `grace test` or CI.

---

## Self-review

- **Spec coverage:** Integer bar %, legend counts + meta + pill + per-section accent, a11y, zero-total → `0%` each—mapped above.
- **Placeholders:** None.
- **Types:** `ReviewStatsSectionKind`, `ReviewWeekSectionTotals` unchanged; percents are `[Int]` parallel to widths.

**Plan complete:** `docs/superpowers/plans/2026-04-10-past-section-mix-247.md`. Execute inline in-repo (this session) or subagent-driven per your workflow.
