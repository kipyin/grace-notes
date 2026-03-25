---
initiative_id: 021-issue-85-insights-screen-follow-through
role: Architect
status: completed
updated_at: 2026-03-24
related_issue: 85
related_pr: none
---

# Architecture

## Inputs Reviewed

- `brief.md`, `design.md`, `ReviewScreen.swift`, `ReviewSummaryCard.swift`, `AppNavigationModel.swift`, `Localizable.xcstrings`.

## Decision

- **Navigation:** `ReviewScreen` gains `@EnvironmentObject AppNavigationModel` and passes `onContinueToToday: { appNavigation.selectedTab = .today }` into `ReviewSummaryCard`. No new routes; `JournalScreen()` on Today remains default when the tab is selected.
- **Thin-week CTA:** `ReviewSummaryCard` accepts `weekJournalEntryCount: Int` and `onContinueToToday: () -> Void`. Show CTA when `!isLoading && (insights == nil || weekJournalEntryCount < 4)`.
- **Layout / hierarchy:** Extend `ReviewInsightInsetPanel` with `TitleEmphasis` (`.lead` vs `.supporting`) mapping to font + background + stroke per `design.md`.
- **Segmented control:** Implement `ReviewModeSegmentedControl` as a system segmented `Picker` with `.pickerStyle(.segmented)`; keep `accessibilityIdentifier("ReviewModePicker")` and hint on container.
- **Strings:** Update **values** in `Localizable.xcstrings` for keys `A thread`, `On-device`; add `Write today's reflection` (+ zh). Swift call sites keep existing `String(localized:)` keys where the catalog key is the legacy English string.
- **Engine (aligned with #85 / tests):** `WeeklyInsightRuleEngine.reflectionDayCount` counts days with reading notes or reflections; `WeeklyInsightCandidateBuilder.narrativeSummary(from:)` returns the observation for single-insight sparse weeks with `dayCount > 0` (still `nil` for the empty-week starter).

## Rationale

Centralizes review-only UI changes; avoids expanding `AppNavigationModel` until a second deep-link appears.

## Risks

Threshold `< 4` is heuristic; UI tests do not cover Review insights today—manual UAT on device/simulator.

## Open Questions

- None.

## Next Owner

`Test Lead` / `QA Reviewer` — confirm close criteria on macOS; then `Release Manager`.
