# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

**Grace Notes** is a native iOS journaling app (SwiftUI + SwiftData). It is a single Xcode project with zero third-party dependencies. See `README.md` for features and project structure.

### Platform constraint

This project **requires macOS + Xcode 15+** to build, run, and test. The Cloud Agent Linux VM cannot compile Swift code that depends on iOS SDK frameworks (SwiftUI, SwiftData, UIKit). There is no backend, no API server, and no web UI—everything runs on-device in the iOS Simulator.

### What works on Linux

- **Linting**: `swiftlint lint` (invoke `swiftlint` from PATH; binary location can vary by environment). In Cursor Cloud Linux, the static SwiftLint binary is preinstalled and runs without the Swift toolchain; it reports style violations across all Swift source files. The dynamic SwiftLint binary will crash on Linux because `libsourcekitdInProc.so` is unavailable, so use the static variant there.
- **Code review / static analysis**: Reading and reviewing Swift source files.

### What does NOT work on Linux

- `xcodebuild build` / `xcodebuild test` — requires macOS + Xcode + iOS Simulator.
- Running the app in the iOS Simulator — requires macOS.
- Unit tests (`GraceNotesTests`) and UI tests (`GraceNotesUITests`) — require Xcode test runner.

### Build and test commands (macOS only)

```bash
xcodebuild \
  -project GraceNotes/GraceNotes.xcodeproj \
  -scheme GraceNotes \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  test
```

### Lint command

```bash
swiftlint lint
```

Runs from the repo root; lints all `.swift` files recursively. Currently reports 10 violations (9 warnings, 1 error) across 59 files. The `statement_position` rule is skipped because it requires SourceKit (unavailable in the static binary). Exit code 2 is expected when there are error-level violations; this does **not** mean the tool failed.

On macOS, install SwiftLint via Homebrew if needed:

```bash
brew install swiftlint
```

---

## Role governance

Keep role behavior in `.agents/skills/` as the single source of truth for role-specific instructions (same tree as Impeccable task skills). Use short role names and mapped files:

- `Strategist` -> `.agents/skills/strategist/SKILL.md`
- `Designer` -> `.agents/skills/designer/SKILL.md`
- `Architect` -> `.agents/skills/architect/SKILL.md`
- `Translator` -> `.agents/skills/translator/SKILL.md`
- `Builder` -> `.agents/skills/builder/SKILL.md`
- `Release Manager` -> `.agents/skills/release-manager/SKILL.md`
- `QA Reviewer` -> `.agents/skills/qa-reviewer/SKILL.md`
- `Test Lead` -> `.agents/skills/test-lead/SKILL.md`
- Role index and shared contract -> `.agents/skills/roles-index/SKILL.md`

Use `GraceNotes/docs/agent-log/` as the canonical source for role-to-role interaction, handoffs, and deferred pushback context.

Keep `AGENTS.md` focused on global constraints that apply to every role, while `.agents/skills/` defines role behavior for the mapped roles above.

## Code style

The goal is not maximal abstraction or maximal cleverness. The goal is code that is small, calm, readable, and hard to break.

### Aesthetic

- Prefer **boring code over surprising code**. Avoid clever one-liners, operator overloading for non-obvious semantics, or patterns that require deep familiarity to understand.
- Keep types and extensions **small in concept count**. A file should have one primary responsibility. If a type grows large, split by concern (e.g., separate view modifiers from view logic).
- Use **clear names** that match the product language. If the UI says "Gratitudes", the code should use `gratitudes`. Prefer `JournalEntry` over `JEntry`, `SequentialSectionView` over `SeqSection`.
- **User-facing English** (`Localizable.xcstrings`, alerts, permissions, onboarding): use **American English** spelling (e.g. *Summarize*, *color*, *behavior*).
- Make the **main flow easy to scan**: load data → render UI → handle user action → update state → persist. Keep view bodies readable; extract complex subviews with clear names.
- Prefer a **single obvious representation** for a piece of data. Avoid bouncing between SwiftData `@Model`, DTOs, and ad hoc tuples unless there is a strong reason. Use `JournalExportPayload` for sharing, not raw `JournalEntry`.
- Keep comments sparse. Add them when they explain **why** something exists or a non-obvious constraint (e.g., "NL extraction can return nil for very short input"). Do not narrate obvious code.
- Avoid "magic helper" sprawl. A helper or extension should either simplify the reader's job, or it should not exist. Prefer a small, well-named function over a generic utility that obscures intent.

### Hygienic

- Keep **boundaries explicit**: `Data` defines models and persistence; `JournalRepository` implements queries and writes; `Services` orchestrate cross-cutting behavior (e.g., summarization); Views and ViewModels translate UI state into typed app-level actions. Views should not import or manipulate SwiftData context directly; ViewModels coordinate with repositories.
- Prefer **typed contracts** for non-trivial flows: `Summarizer` protocol, `JournalExportPayload`, `SummarizationResult`. Avoid passing raw `[String]` or `Any` when a domain type makes intent clear.
- Do not create abstractions just to move code around. A new protocol, type, or module should reduce ambiguity, coupling, or duplication. If you cannot name it clearly, defer the abstraction.
- Preserve **one source of truth** for important behavior. Completion logic, validation, and export formatting should not be reimplemented differently in multiple layers. Centralize in ViewModel or repository as appropriate.
- Keep public APIs and documentation in sync. If a function's behavior or preconditions change, update call sites, tests, and any doc comments in the same change.
- When renaming or refactoring legacy paths, prefer a **clear primary name** plus a temporary compatibility shim (e.g., a deprecated typealias) rather than letting two concepts coexist indefinitely.

### Robust

- Validate inputs **before destructive actions**. Check array bounds, non-empty strings where required, and valid indices before persisting or mutating shared state.
- Fail with **clean, actionable messages** for users (e.g., "Unable to save your journal entry.") and **specific logs** for developers when debugging. Prefer `saveErrorMessage` or `@Published` error state over silent failure.
- Prefer code that is easy to test with **targeted unit tests** and a few integration/smoke tests over code that only works when driven through the UI. Inject `JournalRepository`, `Summarizer`, and `nowProvider`/`Calendar` into ViewModels so tests can substitute mocks.
- Make hidden global state explicit when practical. Prefer `PersistenceController.shared` with a clear name over singletons scattered in extensions. Use `@Environment(\.modelContext)` in views; pass context explicitly into ViewModels.
- Handle real edge cases: empty input on submit, nil from NL summarizer, maximum slot count (5), not-yet-persisted entries, SwiftData save failures. Document assumptions (e.g., "gratitudes count ≤ 5").
- If a refactor changes behavior in a subtle UI or persistence path, add or update a test so the intended behavior is locked in.

### Practical preferences

- SwiftUI + SwiftData is the stack. The app should stay **portable in shape**: favor patterns that would still make sense with a different persistence layer (e.g., Core Data) or a future widget. Keep business logic outside view bodies.
- SwiftData and `@Model` are intentionally simple. Use `@Attribute(.externalStorage)` only when size justifies it. Keep schema changes minimal; avoid heavy migrations in early development.
- **SwiftLint** is the style authority. Fix violations before committing. Use the static binary on Linux (`swiftlint lint`); the project may add a config file later.
- When in doubt, choose: fewer layers, fewer representations, fewer special cases, more explicit names, more local reasoning.
- Prefer `struct` for value types (payloads, config) and `class` only when reference semantics or `ObservableObject` are required. Use `@MainActor` for UI-related types.

**One-sentence summary:** Write code that looks calm, says exactly what it means, and keeps behavior in the smallest sensible number of places.
