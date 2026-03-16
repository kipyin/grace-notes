# Code Quality Analysis Plan

This document outlines a systematic plan to analyze the Five Cubed Moments codebase against the three pillars in AGENTS.md (Aesthetic, Hygienic, Robust), assess test coverage, and evaluate modern idiomatic Swift usage. It is intended as a roadmap for periodic or deeper analysis—not a full analysis itself.

---

## 0. Initial Snapshot (Preliminary)

A quick inspection suggests the codebase is **generally solid** and aligned with AGENTS.md. Summary:

| Pillar | Impression | Notes |
|--------|-------------|-------|
| **Aesthetic** | Good with caveats | Clear names, single representation (`JournalExportPayload`), sparse comments. `JournalScreen` is large (341 lines) and one function has high cyclomatic complexity; extraction recommended. |
| **Hygienic** | Strong | Explicit boundaries (Views → ViewModel → Repository), typed contracts (`Summarizer`, `SummarizationResult`), shared completion logic (`JournalEntry.criteriaMet`). |
| **Robust** | Good | Input validation in add/update/remove, `saveErrorMessage` for users, injection points for testing. Fallback when summarizer fails. |

**Tests:** Repository, ViewModel, and NaturalLanguageSummarizer are well exercised. CloudSummarizer, JournalShareRenderer, SummarizerProvider, SettingsScreen, and share/photo flows are untested. UI tests cover Today persistence, History navigation, and Share visibility.

**Swift:** Uses SwiftData `@Model`/`#Predicate`, `async/await`, `@MainActor`, Combine for debounce, `String(localized:)`. Idiomatic overall.

**SwiftLint:** 46 violations (7 errors). Main issues: `identifier_name` (`vm`, `c`, `t`, `r`, `g`, `b`), `JournalScreen` complexity/body length, and `line_length`.

---

## 1. Scope and Goals

### What to Analyze

- **Production Swift files** (17 files under `FiveCubedMoments/`)
- **Test files** (4 under `FiveCubedMomentsTests/`, 3 under `FiveCubedMomentsUITests/`)
- **SwiftLint output** as a baseline for style and complexity

### Goals

1. Score and document alignment with AGENTS.md pillars.
2. Identify concrete improvement areas with file/line references.
3. Map test coverage by module and surface gaps.
4. Note Swift idioms and modernization opportunities.

---

## 2. Pillar 1: Aesthetic

*Principle: Code that is small, calm, readable, and hard to break.*

### 2.1 Checklist

| Criterion | Where to Look | Artifacts |
|-----------|---------------|-----------|
| Boring over surprising | No clever one-liners, operator overloading, deep patterns | Grep for `operator`, custom `@propertyWrapper`, complex generics |
| Small concept count per file | One primary responsibility per type | Line count, `type_body_length`, single-purpose files |
| Clear names matching product | `gratitudes`, `JournalEntry`, `SequentialSectionView` | Grep for abbreviations (`JEntry`, `SeqSection`), review naming |
| Main flow easy to scan | load → render → handle → update → persist | Trace `JournalScreen` → `JournalViewModel` → `JournalRepository` |
| Single representation | `JournalExportPayload` for sharing, not raw `JournalEntry` | DTOs vs. `@Model` usage, ad hoc tuples |
| Sparse comments | Explain *why*, not *what* | Comment density, obvious vs. non-obvious |
| No magic helper sprawl | Helpers simplify the reader's job | Extensions and utilities in DesignSystem, Services |

### 2.2 Known Signals (from initial inspection)

- **JournalScreen.swift**: `type_body_length` (341 lines), `cyclomatic_complexity` (18), `function_body_length` (53 lines) — suggests extraction of subviews or section logic.
- **JournalViewModel**: Repetitive `add*/update*/remove*` for gratitudes/needs/people — may be intentional (clarity) or refactorable.
- **Identifier names**: `vm`, `c`, `t`, `r`, `g`, `b` violate SwiftLint `identifier_name` — fix to improve clarity.

### 2.3 Analysis Steps

1. Run `swiftlint lint` and categorize violations by pillar (aesthetic vs. hygienic vs. robust).
2. For each file > 200 lines, list concepts it contains and propose splits.
3. Trace one user flow end-to-end (e.g., add gratitude → persist) and verify it’s easy to follow.
4. Count comment-to-code ratio and flag unnecessary narration.

---

## 3. Pillar 2: Hygienic

*Principle: Explicit boundaries, typed contracts, one source of truth, no unnecessary abstractions.*

### 3.1 Checklist

| Criterion | Where to Look | Artifacts |
|-----------|---------------|-----------|
| Explicit boundaries | Data, JournalRepository, Services, Views/ViewModels | Who imports SwiftData; who touches `ModelContext` |
| Typed contracts | `Summarizer`, `JournalExportPayload`, `SummarizationResult` | Use of `[String]`, `Any`, untyped closures |
| No unnecessary abstractions | Protocols and types should reduce ambiguity | List of protocols/abstractions and their justification |
| One source of truth | Completion logic, validation, export format | `JournalEntry.criteriaMet`, completion rules |
| API/docs in sync | Doc comments and preconditions | `///` comments vs. actual behavior |
| Clear primary names | No legacy aliases without deprecation | Typealiases, dual concepts |

### 3.2 Known Signals

- **Boundaries**: Views use `@Environment(\.modelContext)`; ViewModel receives `ModelContext` via `loadEntry`. Repository is injected in tests. Good separation.
- **Typed contracts**: `Summarizer` protocol, `SummarizationResult`, `JournalExportPayload` — aligned with AGENTS.md.
- **ViewModel init**: `repository: JournalRepository? = nil` — optional injection; production uses default. Document trade-off (simplicity vs. testability).

### 3.3 Analysis Steps

1. Draw a dependency diagram: Views → ViewModels → Repository/Services → Models.
2. Search for `[String]`, `Any`, and untyped params in public APIs.
3. Trace completion/validation logic: is it centralized or duplicated?
4. List all protocols and justify each (or mark for removal).

---

## 4. Pillar 3: Robust

*Principle: Validate inputs, clean errors, testable code, explicit state, handle edge cases.*

### 4.1 Checklist

| Criterion | Where to Look | Artifacts |
|-----------|---------------|-----------|
| Validate before destructive actions | Bounds, non-empty strings, valid indices | `add*/update*/remove*` guards |
| Clean, actionable user messages | `saveErrorMessage`, `@Published` error state | Error strings, localization |
| Testable (injection points) | `calendar`, `nowProvider`, `repository`, `summarizerProvider` | Constructor params in ViewModels |
| Explicit global state | `PersistenceController.shared` vs. scattered singletons | Singleton usage |
| Edge cases | Empty input, nil summarizer, slot limit 5, save failure | Documented assumptions |
| Tests lock in behavior | New tests for subtle refactors | Test presence near risky paths |

### 4.2 Known Signals

- **Validation**: `addGratitude`, `updateGratitude`, etc. use `guard` for empty, slot count, index. Good.
- **Errors**: `saveErrorMessage` for load/save; fallback to NL when cloud summarizer fails.
- **Injection**: `JournalViewModel` accepts `calendar`, `nowProvider`, `repository`, `summarizerProvider` — tests use them.
- **Edge cases**: `JournalRepository.fetchEntry` guards `calendar.date(byAdding:...)`; fallback in `summarizeForChip` for NL failure.

### 4.3 Analysis Steps

1. For each public mutating function, verify preconditions are checked.
2. List all user-facing error paths and verify messages are localized and actionable.
3. Verify each ViewModel/Service can be tested with mocks (no hidden `PersistenceController` or `Date()` in hot paths).
4. Document assumptions (e.g., "gratitudes count ≤ 5") in code or design docs.

---

## 5. Test Coverage Analysis

### 5.1 Current Test Inventory

| Module | Test File | Focus |
|--------|-----------|-------|
| Data | `JournalRepositoryTests` | fetchAllEntries sort, fetchEntry existing/missing |
| Features/Journal | `JournalViewModelTests` | load, persist, add/update/remove, export, validation, autosave |
| Services | `NaturalLanguageSummarizerTests` | empty, whitespace, nouns, truncation, section filtering, Chinese |
| UI | `JournalUITests` | Today persist across relaunch, History navigation, Share visibility |
| UI | `FiveCubedMomentsUITests`, Launch | App launch, basic smoke |

### 5.2 Gaps to Investigate

| Area | Status | Notes |
|------|--------|-------|
| `CloudSummarizer` | No unit tests | HTTP, API key; may require mocking/stubbing |
| `JournalShareRenderer` | No unit tests | Image generation; consider snapshot or integration |
| `PersistenceController` | No unit tests | SwiftData container setup; integration-heavy |
| `SummarizerProvider` | No unit tests | Switching between NL/Cloud |
| `HistoryScreen` | Logic not isolated | UI-driven; could extract date-picker or list logic |
| `SettingsScreen` | No tests | Reminders, preferences |
| `JournalShareCardView` | No tests | Layout, accessibility |
| `SaveToPhotosActivity` | No tests | UIActivity integration |
| Edge cases in ViewModel | Partial | Slot limit (5), negative index, concurrent load |

### 5.3 Analysis Steps

1. List every public type/function and mark: unit-tested, integration-tested, or untested.
2. For untested areas, classify: (a) should have unit tests, (b) integration/UI only, (c) low risk / defer.
3. Consider coverage metrics if/when running on macOS (Xcode coverage).
4. Prioritize: Repository, ViewModel, Summarizers first; Views and Activities second.

---

## 6. Modern Idiomatic Swift

### 6.1 Checklist

| Feature | Where to Check |
|---------|----------------|
| SwiftData | `@Model`, `#Predicate`, `ModelContext`, `ModelContainer` |
| Concurrency | `async/await` (Summarizer), `@MainActor` (ViewModel, tests) |
| Observation | `@Published`, `ObservableObject` vs. `@Observable` (iOS 17+) |
| Localization | `String(localized:)` |
| SwiftUI | `@Environment`, `@StateObject`, `scrollDismissesKeyboard` |
| Value vs. reference | `struct` for payloads, `class` for `ObservableObject` |
| Optional handling | `guard`, `if let`, optional chaining |
| Collection APIs | `map(\.fullText)`, `filter`, `reduce` |

### 6.2 Known Usage

- **SwiftData**: `@Model` on `JournalEntry`, `#Predicate` in `JournalRepository`.
- **Concurrency**: `async/await` in summarization; `@MainActor` on `JournalViewModel`, tests.
- **Combine**: Debounce for autosave.
- **Observation**: `ObservableObject` with `@Published`; could consider `@Observable` (Swift 5.9+) for newer patterns.
- **Localization**: `String(localized: ...)` for UI strings.

### 6.3 Analysis Steps

1. Audit use of deprecated APIs (e.g., `@Published` vs. `@Observable`).
2. Check for `DispatchQueue`/`Thread` usage that could be `async`/actors.
3. Verify `Sendable` conformance where relevant (e.g., `JournalExportPayload`).
4. Review closure capture (e.g., `[weak self]` in Combine) for retain cycles.

---

## 7. SwiftLint Baseline

**Current**: 46 violations, 7 serious (per `swiftlint lint`).

### Violation Summary (for tracking)

| Rule | Count | Files | Priority |
|------|-------|-------|----------|
| `identifier_name` | Many | Tests, JournalScreen, JournalItem, Theme, NaturalLanguageSummarizer | High |
| `line_length` | ~15 | Tests, CloudSummarizer, SettingsScreen | Medium |
| `cyclomatic_complexity` | 1 | JournalScreen | High |
| `function_body_length` | 1 | JournalScreen | High |
| `type_body_length` | 1 | JournalScreen | High |
| `static_over_final_class` | 1 | UITestsLaunchTests | Low |

### Remediation Order

1. Fix `identifier_name` (rename `vm` → `viewModel`, `c`/`t`/`r`/`g`/`b` → descriptive names).
2. Refactor `JournalScreen` (extract subviews, reduce complexity).
3. Fix `line_length` (wrap or extract).
4. Consider `.swiftlint.yml` to codify rules and exclude generated/third-party paths.

---

## 8. Execution Order

### Phase A: Quick Wins (1–2 hours)

1. Run SwiftLint and record full output.
2. Fix identifier names (`vm`, `c`, `t`, `r`, `g`, `b`).
3. Add `.swiftlint.yml` if missing.

### Phase B: Pillar Review (2–4 hours)

4. Walk through Aesthetic checklist; document findings.
5. Walk through Hygienic checklist; document findings.
6. Walk through Robust checklist; document findings.

### Phase C: Test Gap Analysis (1–2 hours)

7. Map tested vs. untested modules.
8. Prioritize tests for CloudSummarizer, JournalShareRenderer, SummarizerProvider.

### Phase D: Structural Refactors (as needed)

9. Split `JournalScreen` (extract sections, reduce complexity).
10. Document any new abstractions or deprecations.

---

## 9. Output Artifacts

After running the plan, produce:

1. **`docs/CODE_QUALITY_REPORT.md`** — Summary scores, findings, and recommendations.
2. **Updated `.swiftlint.yml`** — If created or changed.
3. **Issue backlog** — Concrete tickets for improvements (optional, if using GitHub Issues).

---

## 10. Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-03-16 | — | Initial plan created |
