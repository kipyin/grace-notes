# Improvements inventory

**Snapshot:** 2026-03-24  
**SwiftLint:** `swiftlint lint` — **16** violations, **0** serious, **141** files (refresh before closing issues).  
**GitHub open issues sampled:** `gh issue list --repo kipyin/grace-notes --state open --limit 200`  
**Related docs:** [06-tech-debt-backlog.md](../../../06-tech-debt-backlog.md), [2026-03-code-quality-analysis-plan.md](../../../archive/2026-03-code-quality-analysis-plan.md), [AGENTS.md](../../../../../AGENTS.md)

## Inventory table

| id | area | finding | severity | pillar | gh | action | proposed_milestone | chunk |
|----|------|---------|----------|--------|-----|--------|-------------------|-------|
| INV-001 | Tooling | SwiftLint reports 16 violations; AGENTS.md still describes an older baseline | P2 | Tooling | [#87](https://github.com/kipyin/grace-notes/issues/87) | umbrella A | 0.5.3 | swift-prod |
| INV-002 | Aesthetic | `JournalScreen.swift` exceeds `file_length` (1074 lines) | P1 | Aesthetic | [#87](https://github.com/kipyin/grace-notes/issues/87) | umbrella A | 0.5.3 | swift-prod |
| INV-003 | Aesthetic | `SequentialSectionView.swift` exceeds `file_length` (886 lines) | P1 | Aesthetic | [#87](https://github.com/kipyin/grace-notes/issues/87) | umbrella A | 0.5.3 | swift-prod |
| INV-004 | Aesthetic | `CloudReviewInsightsSanitizer` exceeds `type_body_length` | P2 | Aesthetic | [#87](https://github.com/kipyin/grace-notes/issues/87) | umbrella A | 0.5.3 | swift-prod |
| INV-005 | Hygienic | `WeeklyInsightCandidateBuilder` invalid `swiftlint:disable` (blanket_disable_command) | P2 | Hygienic | [#87](https://github.com/kipyin/grace-notes/issues/87) | umbrella A | 0.5.3 | swift-prod |
| INV-006 | Aesthetic | `PostSeedJourneyView` short identifier names (`w`, `h`) | P3 | Aesthetic | [#87](https://github.com/kipyin/grace-notes/issues/87) | umbrella A | 0.5.3 | swift-prod |
| INV-007 | Hygienic | `PersistenceController` `unused_optional_binding` | P3 | Hygienic | [#87](https://github.com/kipyin/grace-notes/issues/87) | umbrella A | 0.5.3 | swift-prod |
| INV-008 | Tooling | `ReviewInsightsProviderTests` type body length | P3 | Tooling | [#88](https://github.com/kipyin/grace-notes/issues/88) | umbrella B | 0.5.3 | swift-test |
| INV-009 | Tooling | `DeterministicReviewInsightsGeneratorTests` type body length | P3 | Tooling | [#88](https://github.com/kipyin/grace-notes/issues/88) | umbrella B | 0.5.3 | swift-test |
| INV-010 | Tooling | `JournalViewModelMutationTests` type body length | P3 | Tooling | [#88](https://github.com/kipyin/grace-notes/issues/88) | umbrella B | 0.5.3 | swift-test |
| INV-011 | Tooling | `PersistenceRuntimeSnapshotTests` identifier_name | P3 | Tooling | [#88](https://github.com/kipyin/grace-notes/issues/88) | umbrella B | 0.5.3 | swift-test |
| INV-012 | Tooling | `JournalUITests` line_length | P3 | Tooling | [#88](https://github.com/kipyin/grace-notes/issues/88) | umbrella B | 0.5.3 | swift-test |
| INV-013 | Tests | Share / save-to-photos / `JournalShareRenderer` coverage remains thin vs core journal flows | P2 | Tests | [#89](https://github.com/kipyin/grace-notes/issues/89) | umbrella C | 0.6.1 | coverage |
| INV-014 | Tests | `SettingsScreen` and deep settings navigation under-tested relative to surface area | P2 | Tests | [#89](https://github.com/kipyin/grace-notes/issues/89) | umbrella C | 0.6.1 | coverage |
| INV-015 | Tests | `JournalScreenChipHandling` orchestration: coverage gap noted in tech-debt doc | P2 | Tests | [#89](https://github.com/kipyin/grace-notes/issues/89) | umbrella C | 0.6.1 | coverage |
| INV-016 | Architecture | `JournalViewModel` carries many concerns (persistence, debounce, summarization, streaks, export) | P1 | Hygienic | [#90](https://github.com/kipyin/grace-notes/issues/90) | umbrella D | 0.6.0 | vm-split |
| INV-017 | Architecture | Domain `bibleNotes` vs UI “Reading Notes” terminology drift | P3 | Hygienic | [#90](https://github.com/kipyin/grace-notes/issues/90) | umbrella D | 0.6.0 | vm-split |
| INV-018 | Product | Settings section headers title case | P2 | Product | [#84](https://github.com/kipyin/grace-notes/issues/84) | existing | 0.5.2 | insight-settings |
| INV-019 | Product | Review insights optional placement for AI / on-device source label | P2 | Product | [#83](https://github.com/kipyin/grace-notes/issues/83) | existing | 0.5.2 | insight-settings |
| INV-020 | Product | Design critique: Review Insights hierarchy polish | P2 | Product | [#85](https://github.com/kipyin/grace-notes/issues/85) | existing | 0.5.2 | insight-settings |
| INV-021 | Product | Surface Cloud AI insight / summarization status to users | P2 | Product | [#86](https://github.com/kipyin/grace-notes/issues/86) | existing | 0.5.2 | insight-settings |
| INV-022 | Product | Review deep insight engine (prompts, fixtures, contract) | P1 | Product | [#80](https://github.com/kipyin/grace-notes/issues/80) | existing | 0.5.2 | insight-settings |
| INV-023 | Product | Check mark after five entries complete in a section | P3 | Product | [#11](https://github.com/kipyin/grace-notes/issues/11) | existing | 0.5.0 | legacy-milestone |
| INV-024 | Product | Reconsider streak presentation | P2 | Product | [#35](https://github.com/kipyin/grace-notes/issues/35) | existing | 0.8.x+ | streak |

## Parking lot (not given new issues this pass)

- **CI / Linux:** Keep documenting macOS-only verification where AGENTS.md already states constraints.
- **Localization `zh-Hant`:** Already on roadmap under 0.6.0; no duplicate issue.
- **`#50` orientation toggle:** Already on roadmap 0.6.0; no duplicate issue.

## Dedupe keys

Use lowercase slug of first six words of finding for matching future audits, e.g. `journals-screen-file-length`, `journal-viewmodel-multi-responsibility`.
