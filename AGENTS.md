# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

**Grace Notes** is a native iOS journaling app (SwiftUI + SwiftData). It is a single Xcode project with zero third-party dependencies. See `README.md` for features and project structure.

**Release versioning (summary):** Prefer a **fixed marketing version** per roadmap line with **incrementing build** for each TestFlight/App Store binary; git tags **`v{marketing}+{build}`** (e.g. `v0.5.0+8`). Full convention: `.agents/skills/vc/SKILL.md` → **Versioning**.

### Platform constraint

This project **requires macOS + Xcode 26+** to build, run, and test with the **default** Makefile simulator destinations (iPhone 17 family / iOS 26 runtimes). The Cloud Agent Linux VM cannot compile Swift code that depends on iOS SDK frameworks (SwiftUI, SwiftData, UIKit). There is no backend, no API server, and no web UI—everything runs on-device in the iOS Simulator.

### What works on Linux

- **Linting**: `swiftlint lint` (invoke `swiftlint` from PATH; binary location can vary by environment). In Cursor Cloud Linux, the static SwiftLint binary is preinstalled and runs without the Swift toolchain; it reports style violations across all Swift source files. The dynamic SwiftLint binary will crash on Linux because `libsourcekitdInProc.so` is unavailable, so use the static variant there.
- **Code review / static analysis**: Reading and reviewing Swift source files.

### What does NOT work on Linux

- `xcodebuild build` / `xcodebuild test` — requires macOS + Xcode + iOS Simulator.
- Running the app in the iOS Simulator — requires macOS.
- Unit tests (`GraceNotesTests`) and UI tests (`GraceNotesUITests`) — require Xcode test runner.

### Build and test commands (macOS only)

Prefer **`make`** from the repo root so destinations and flags stay aligned with `Makefile` (`make ci`, `make test`, `make test-matrix`). Destinations are validated/resolved by `Scripts/simulator_destination.py` (Python 3). For copy-paste `platform=…` strings, run `make list-simulator-destinations`.

CI uses **GitHub Actions** with **`make lint`** + **`make ci-build`** on PRs to **`main`**, **`make ci-merge-queue`** on **`merge_group`** / **`full-ci`** / rare **`main`** pushes. Runners select **Xcode 26.3** and use **iPhone 17 Pro @ iOS 26.3** plus **iPhone XR @ iOS 17.5** (`CI_SIMULATOR_PRO` / `CI_SIMULATOR_XR`) without downloading simulator platforms in workflow steps. See **CI (GitHub Actions)** in [`README.md`](README.md).

```bash
make ci
# or, ad hoc:
xcodebuild \
  -project GraceNotes/GraceNotes.xcodeproj \
  -scheme GraceNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  test
```

Automated Makefile targets test the **GraceNotes** scheme only. The **GraceNotes (Demo)** scheme remains in Xcode for local runs with demo seed data; it is not part of `make test` / `make ci`.

### Lint command

```bash
swiftlint lint
```

Runs from the repo root; lints all `.swift` files recursively per `.swiftlint.yml`. The `statement_position` rule is skipped because it requires SourceKit (unavailable in the static binary). Exit code 2 is expected when there are error-level violations; this does **not** mean the tool failed.

On macOS, install SwiftLint via Homebrew if needed:

```bash
brew install swiftlint
```

---

## How agents work here

**Small change (default):** Implement and open a PR. Say in a short paragraph what changed and how you verified it. No extra repo docs, no fixed “role relay,” and no issue required if the change is obvious.

**GitHub issue:** Use one when product intent or acceptance should outlive the chat — write in plain language, not forms or required section headers.

**Specialist skills:** `.agents/skills/` holds optional roles (Strategist, Architect, Builder, and others). Attach or follow them **only** when work is ambiguous, high-risk, or you explicitly want that lens — not as a default pipeline.

**Handoffs:** Put anything the next person needs in the **PR** or **linked issue** (description or comments). This repo does not use a separate handoff folder.

## Role index (optional specialists)

Behavior for each role lives in `.agents/skills/`. Shared vocabulary and quality expectations: `.agents/skills/roles-index/SKILL.md`.

| Role | Skill file |
|------|------------|
| Strategist | `.agents/skills/strategize/SKILL.md` |
| Architect | `.agents/skills/architect/SKILL.md` |
| Designer | `.agents/skills/design/SKILL.md` |
| Translator | `.agents/skills/translate/SKILL.md` |
| Marketing | `.agents/skills/promote/SKILL.md` |
| Builder | `.agents/skills/build/SKILL.md` |
| Release Manager | `.agents/skills/vc/SKILL.md` |
| QA Reviewer | `.agents/skills/qa-review/SKILL.md` |
| Test Lead | `.agents/skills/test/SKILL.md` |

`housekeep` is **deprecated** (see `.agents/skills/housekeep/SKILL.md`).

Keep `AGENTS.md` focused on global constraints; use skills when they help, not by default.

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
