# Grace Notes

Guided daily reflection for gratitude, needs, and people in mind.

## Why Grace Notes

Grace Notes (`感恩记`) is for people who want more than a blank page, a streak counter, or a rotating list of prompts. Many journaling apps help you write, but do not help your writing add up to reflection. Grace Notes gives each day a clear structure, then helps patterns emerge over time.

The app centers three lenses that belong together:

- **Gratitudes** - not to deny difficulty, but to interrupt the mindset that life is only happening against you or owes you something.
- **Needs** - to name what is actually missing, needed, or neglected instead of staying vague.
- **People in Mind** - to widen attention beyond the self and keep relationships in view.

## How The Sections Work Together

Each section is useful on its own, but the value compounds when they are read together. Repeated needs can show where something important stays unnamed or unaddressed. Gratitudes can reveal where care, provision, or progress is already present. People in Mind can show where attention, concern, and responsibility keep returning.

Across a week, those parts create a more useful picture than a single mood or generic diary page. You may notice that a need keeps appearing without movement, that it never shows up alongside gratitude, or that a person and a gratitude keep recurring together. Grace Notes is built to help **Journals** add up to weekly reflection, not just accumulate in an archive.

## Why It Feels Different

Grace Notes is lightweight, private by default, and still powerful enough to surface patterns. **Journals** save as you type, summaries on **Past** stay on-device, and JSON export/import keeps ownership with you. In a category crowded with cloud-first AI products, Grace Notes aims to stay useful without turning reflection into a black box or making AI a prerequisite.

## Features

- **Today** – For each calendar day the user creates a **Journal** with three **Sections** (Gratitudes, Needs, People in Mind), each with up to five **Entries**, plus **Reading Notes** and **Reflections** (together, **Notes**; a future version will merge these into one **Notes** field). Journals auto-create and save as you type.
  - **Sequential input** – Type a full sentence, press Enter; each **Entry** stays easy to read. Tap an Entry to edit inline. Each **Section** holds up to five Entries.
- **Past** – Browse Journals by month, see weekly rhythm and insights, and reopen saved days from the timeline. Layout uses **Cards** (for example a day **Card**, a completion / growth-stage **Card**, and other Past modules).
- **Weekly insights** – Recurring **Themes** extracted from **Entries** (not “chips”), continuity prompts, and a deterministic weekly summary generated on-device.
- **Privacy and ownership** – Storage is private by default, with JSON export/import for backup and ownership plus optional iCloud sync when you want it.
- **Shareable cards** – Generate a formatted image of a Journal and share via the iOS share sheet.
- **Reminders and onboarding** – Optional daily reminders plus guided first-Journal milestones and suggestions for reminders and iCloud.
- **Habit support** – Streak plus **Completion status** on the three **Sections**; “perfect” streak days match **Bloom** (all fifteen Entries). **Notes** do not change **Completion status**.

## Release notes

Version history, per-build notes, and git tag shape (**`v{marketing}+{build}`**, e.g. **`v0.5.0+10`**) are maintained in [CHANGELOG.md](CHANGELOG.md).

### Roadmap

**Shipped** scope is authoritative in **CHANGELOG.md**. **Forward** work is sequenced with [GitHub milestones and issues](https://github.com/kipyin/grace-notes/milestones) on [kipyin/grace-notes](https://github.com/kipyin/grace-notes). Milestones name **scope lanes**, not necessarily a new App Store **marketing** version every time. The app ships a **fixed marketing version per line** with a **monotonic build**; tags look like **`v{marketing}+{build}`**. Bump marketing only when opening the next line. Full convention: `.agents/skills/vc/SKILL.md` (**Versioning**).

## Terminology (contributors)

Use this vocabulary in README, issues, PRs, and **new** Swift identifiers. Issue **#144** tracks renaming the codebase to match. Old spellings may persist only in **legacy decode / migration** code (string literals, UserDefaults migration, import of older JSON).

### Product terms (English)

1. **Journal** — What the user creates for **one calendar day** on **Today**. Do **not** call it a note, reflection, *journal entry*, or generic *entry* when you mean the day-level object. **Swift type:** `Journal`.
2. **Today** — The main journaling tab. Say **Today**, not “today’s journal,” “today’s entry,” or “Journal” when you mean the tab.
3. **Past** — The history and insights tab. Say **Past**, not Review, Insights, or Reflections when you mean this destination.
4. **Section** — One of **three** on each Journal: **Gratitudes**, **Needs**, **People in Mind**. Do **not** use *structured* as an adjective for these groups.
5. **Entry** — One of up to **five** items inside a **Section**. Do **not** call these lines, chips, strips, or sentences in new prose or identifiers. **Swift type:** `Entry`. *Note:* English **Entry** (section row) is not the same as day-level **Journal**.
6. **Notes** — Reading notes and reflections on a Journal. Treat them as **Notes** in docs; the app still has two fields until they merge into a single **Notes** field—avoid coupling Section **Entries** with Notes in new designs.
7. **Theme** — On **Past**, analytics can surface **Themes** extracted from **Entries** (and related text). Do **not** call these chips.
8. **Card** — A boxed module on **Past** (e.g. a day **Card**, growth-stage **Card**). Say **Card** in contributor prose, not generic *box*.
9. **Completion status** — Per Journal, derived **only** from how many **Entries** are in each **Section**; **Notes** do not affect it. Implemented as `JournalCompletionLevel`. Each status has:
   - **Completion name** — Soil, Sprout, Twig, Leaf, Bloom.
   - **Completion symbol** — The visual glyph for that stage.
   - **Completion badge** — Symbol + name. Say **badge**, not pill.
10. **Bloom** — All **five Entries** filled in **each** Section (fifteen Entries total). Same as `.bloom` and what **perfect** streak and first-run milestones use for “all fifteen.”
11. **Bloom Mode** — The Today appearance option with warm styling and motion (**not** “Summer mode”). Persisted as `JournalAppearanceMode.bloom` (`UserDefaults` may still contain legacy `"summer"` until migration runs once at launch).

### Simplified Chinese (user-facing)

Follow **`Localizable.xcstrings`**. Prefer **记录** for day-level **Journal**, **部分** for **Section**. Per-Section slots should move toward terminology consistent with **Entry** as English copy is updated. Avoid **句子条** in completion or tutorial wording. Do not reintroduce **Abundance** or **满溢** in customer strings.

### Completion names (catalog)

| `JournalCompletionLevel` | Completion name | zh-Hans (catalog) | Legacy raw strings (decode only) |
|--------------------------|-----------------|-------------------|----------------------------------|
| `.soil` | Soil | 静待播种 | `soil`, `empty` |
| `.sprout` | Sprout | 初露新芽 | `sprout`, `started`, `seed` |
| `.twig` | Twig | 枝条初成 | `twig`, `growing` |
| `.leaf` | Leaf | 叶茂成形 | `leaf`, `balanced`, `ripening` |
| `.bloom` | Bloom | 花开有成 | `bloom`, `full`, `harvest`, `abundance` |

### Main tabs

**Today** (journaling), **Past** (history and insights), **Settings**. The full-screen **App Tour** (`AppTourView`) can open from Today or Settings; eligibility uses at least one **Entry** in each **Section** (1/1/1) plus related flags.

## Requirements

- Xcode 26 or later (defaults in [`gracenotes-dev.toml`](gracenotes-dev.toml) use iPhone 17 Pro @ `OS=latest` and **iPhone SE (3rd generation) @ iOS 18.5** for the SE test/smoke matrix—override in TOML if your Xcode installs differ)
- iOS 17+ (app deployment target; see the Xcode project)

## Getting Started

1. Clone the repository.
2. Open `GraceNotes/GraceNotes.xcodeproj` in Xcode.
3. For code signing, select your development team in the project's Signing & Capabilities (if needed).
4. Select a simulator or device and run (⌘R). For a preview with sample **Journals**, use the *GraceNotes (Demo)* scheme.

## Automation

Dev automation lives in the **`gracenotes-dev`** Python package ([`Scripts/gracenotes-dev/`](Scripts/gracenotes-dev/)). After install, use **`grace`** or **`python3 -m gracenotes_dev`** from the **repository root** — they are the only supported CLI entrypoints (no `Makefile` targets). Automated flows use the **GraceNotes** scheme only; the **GraceNotes (Demo)** scheme stays in Xcode for ⌘R with sample data.

**Install** (pick one):

```bash
python3 -m pip install -e Scripts/gracenotes-dev
# recommended isolated tool: puts `grace` on PATH
uv tool install --editable ./Scripts/gracenotes-dev
# no install: ephemeral
uv run --project Scripts/gracenotes-dev grace --help
```

**`gracenotes-dev` tests** (stdlib **`unittest`**, [`Scripts/gracenotes-dev/tests/`](Scripts/gracenotes-dev/tests/)):

```bash
cd Scripts/gracenotes-dev && uv run python -m unittest discover -s tests
# or, from repo root after `pip install -e Scripts/gracenotes-dev`:
python3 -m unittest discover -s Scripts/gracenotes-dev/tests
```

- `grace lint` – SwiftLint (requires `swiftlint` on your PATH).
- `grace build` – Simulator build (macOS + Xcode). Use **`grace build --clean`** for `xcodebuild clean` then build (local troubleshooting; **CI does not** run clean by default).
- `grace clean` – `xcodebuild clean` for the configured scheme and destination (same options as `grace build`; use when you would use Xcode’s Clean Build Folder).
- `grace test` – Unit + UI tests; add `--kind unit` / `--kind ui` / `--kind smoke`, `--matrix`, `--isolated-dd`, `--no-reset-sims` as needed.
- `grace ci` – Default CI profile from `gracenotes-dev.toml` (`defaults.default_ci_profile`, **`lint-build`**: lint and simulator build on iPhone 17 Pro). Use **`grace ci --profile lint-build-test`** or **`test-all`** when you need lint + tests locally.
- `grace interactive` – TTY menu to pick a CI profile, then run it (use `grace ci --profile …` in CI or when stdin is not a terminal).
- `grace ci --profile test-all` – Lint, reset simulators, then full tests (no separate build step; close to the old lint + reset + test gate).
- `grace ci --profile full` – Lint, tests on iPhone 17 Pro, UI smoke on iPhone SE (3rd generation) @ iOS **18.5** per `gracenotes-dev.toml`.
- `grace sim runtime install` / `grace sim runtime list` / `grace sim runtime delete …` – Install and manage simulator runtimes (then use `grace sim list` to confirm destination availability).
- `grace sim list` / `grace sim list --physical` / `grace sim resolve SPEC` / `grace sim reset` – Simulator destinations, connected **physical** devices (as `platform=iOS,id=…`), and hygiene.
- `grace sim add` – Create a Simulator instance with `grace sim add "Device Name@os"` or `grace sim add -i` for separate device-type and iOS runtime prompts (install runtimes with `grace sim runtime install` first). Pair with `grace doctor` when a default destination will not resolve.
- `grace run` – Build, install, and launch on a booted **simulator** or a **connected, provisioned** device (`xcrun devicectl` for install/launch after `xcodebuild`). Use `--preset` and `--` to pass [app process arguments](GraceNotes/GraceNotes/Application/GraceNotesApp.swift).
- **Physical devices:** use `grace sim list --physical` to copy a destination, then `grace build --destination 'platform=iOS,id=…'` / `grace run …`. Code signing and team selection remain Xcode’s responsibility. **`grace test`** stays simulator-only ([issue #175](https://github.com/kipyin/grace-notes/issues/175) scope).

Examples:

```bash
grace build --clean
grace test --destination 'iPhone 17 Pro@latest'
grace test --matrix
grace run --destination 'iPhone 17 Pro@latest' -- -reset-journal-tutorial
grace sim add 'iPhone 17 Pro@18.5'
grace sim list --physical
grace run --destination 'platform=iOS,name=Your iPhone'
```

On iOS 17 simulators, **grace** applies targeted `-skip-testing` flags for a few hosted SwiftData suites that crash before assertions; see [`gracenotes-dev.toml`](gracenotes-dev.toml) (`legacy_runtime_skip_flags`).

If `grace lint` reports that SwiftLint is missing:

```bash
brew install swiftlint
```

Note: `grace ci --profile test-all` resets simulators before testing to reduce flaky preflight failures.

## CI (GitHub Actions)

Workflows: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (lint + build on PRs; full lint, test, and smoke on post-merge / **`full-ci`**) and [`.github/workflows/codeql.yml`](.github/workflows/codeql.yml) (CodeQL Swift). **CodeQL** installs **`gracenotes-dev`** and runs **`grace build`** for the traced compile. **CodeQL** runs **daily** at **20:00 UTC** (**04:00 UTC+8**). The CodeQL workflow stores the last successfully analyzed `main` commit in **`actions/cache`** (a new cache entry per commit so the marker can advance); scheduled runs **skip** the traced macOS build when that marker matches the current `main` tip. A cache **miss** or **eviction** still runs the full scan. **Run workflow** (`workflow_dispatch`) on CodeQL always performs a full analysis.

**CI workflow (`ci.yml`).** macOS jobs install **`Scripts/gracenotes-dev`** and run **`grace`** (`grace ci` on PRs — default **`lint-build`**; `grace ci --profile full` for post-merge and **`full-ci`** PRs). Destinations and flags match [`gracenotes-dev.toml`](gracenotes-dev.toml).

**Why not both `push` and `pull_request` on every branch?** A push to a PR branch used to trigger *two* workflow runs (push + pull_request), which was noisy. The workflow now uses **`pull_request` only for PRs targeting `main`**, and **`push` only for the `main` branch** (post-merge build). Feature branches without a PR do not run CI until you open one.

| When | What runs |
|------|-----------|
| **Pull request → `main`** | **Lint & build (iPhone 17 Pro)** — `grace ci` (default profile **`lint-build`**; no tests). **`CI_SIMULATOR_PRO`** is **iPhone 17 Pro @ `OS=latest`**. **`CI_SIMULATOR_XR`** (reserved for **`full`** / matrix jobs that need SE) is **iPhone SE (3rd generation) @ iOS 18.5**. |
| **Push → `main`** | **Main push — lint, test, UI smoke** — `grace ci --profile full` (lint, full tests on **iPhone 17 Pro**, UI smoke on **iPhone SE (3rd generation) @ iOS 18.5** per config). Smoke: `GraceNotesSmokeUITests.testSmokeLaunch`. Skipped when the push SHA is the **`merge_commit_sha`** of a PR merged into **`main`** and that PR is labeled **`no-ci`** (avoids unrelated PRs on the same commit). |
| **Pull request + label `full-ci`** | **PR full-ci — lint, test, UI smoke** — `grace ci --profile full`. Re-runs on new commits while the label is present. |

The **`full-ci`** and **`no-ci`** labels must exist in the GitHub repo (Issues → Labels). Adjust **`CI_SIMULATOR_PRO`** / **`CI_SIMULATOR_XR`** in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and [`gracenotes-dev.toml`](gracenotes-dev.toml) if Apple or runner images change.

**Branch protection:** Configure required status checks for your merge policy—for example **Lint & build (iPhone 17 Pro)** on PRs, and optionally **Main push — lint, test, UI smoke** after merges. That PR job runs on the pull-request SHA only; add **PR full-ci** (label) when you need **`full`** (including UI smoke on SE) before merge. If you used GitHub merge queue before, remove merge queue and any obsolete required checks in **Settings → Branches**.

## Tech Stack

- Swift and SwiftUI
- SwiftData for local persistence
- Natural Language framework for summarization
- CloudKit-ready sync configuration for SwiftData
- MVVM-style architecture

## Project Structure

- `GraceNotes/GraceNotes/Application` - App entry point
- `GraceNotes/GraceNotes/Features/Journal` - **Today** and **Past** surfaces (UI, view models, sharing)
- `GraceNotes/GraceNotes/Data` - Models and persistence (SwiftData); day model **`Journal`**, section row **`Entry`**
- `GraceNotes/GraceNotes/DesignSystem` - Theming and shared styling
- `GraceNotes/GraceNotes/Services` - Summarization and app-level business services

