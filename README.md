# Grace Notes

Structured daily reflection for gratitude, needs, and people in mind.

## Why Grace Notes

Grace Notes (`感恩记`) is for people who want more than a blank page, a streak counter, or a rotating list of prompts. Many journaling apps help you write, but do not help your writing add up to reflection. Grace Notes gives each day a clear structure, then helps patterns emerge over time.

The app centers three lenses that belong together:

- **Gratitudes** - not to deny difficulty, but to interrupt the mindset that life is only happening against you or owes you something.
- **Needs** - to name what is actually missing, needed, or neglected instead of staying vague.
- **People in Mind** - to widen attention beyond the self and keep relationships in view.

## How The Sections Work Together

Each section is useful on its own, but the value compounds when they are read together. Repeated needs can show where something important stays unnamed or unaddressed. Gratitudes can reveal where care, provision, or progress is already present. People in Mind can show where attention, concern, and responsibility keep returning.

Across a week, those parts create a more useful picture than a single mood or diary entry. You may notice that a need keeps appearing without movement, that it never shows up alongside gratitude, or that a person and a gratitude keep recurring together. Grace Notes is built to help entries add up to weekly reflection, not just accumulate in an archive.

## Why It Feels Different

Grace Notes is lightweight, private by default, and still powerful enough to surface patterns. Entries save as you type, weekly reflection summaries stay on-device, and JSON export/import keeps ownership with you. In a category crowded with cloud-first AI products, Grace Notes aims to stay useful without turning reflection into a black box or making AI a prerequisite.

## Features

- **Today** - Structured daily entry with five lines each for Gratitudes, Needs, and People in Mind, plus reading notes and reflections. Entries auto-create and save as you type.
  - **Sequential input** – Type a full sentence, press Enter; your full line stays easy to read on Today. Tap a line to edit inline. Each section holds up to five lines.
- **Past** – Browse past entries by month, review the week's Reflection rhythm, and reopen saved days from the timeline.
- **Weekly insights** – See recurring themes across sections, continuity prompts, and a deterministic weekly reflection summary generated on-device.
- **Privacy and ownership** – Storage is private by default, with JSON export/import for backup and ownership plus optional iCloud sync when you want it.
- **Shareable cards** – Generate a formatted image of a day's entry and share via the iOS share sheet.
- **Reminders and onboarding** – Optional daily reminders plus a guided first-entry path and milestone-based suggestions for reminders and iCloud.
- **Habit support** – Streak plus tiered completion on the structured sections; perfect streak days match a full fifteen-line grid, while reading notes and reflections stay optional.

## Release notes

Version history, per-build notes, and git tag shape (**`v{marketing}+{build}`**, e.g. **`v0.5.0+8`**) are maintained in [CHANGELOG.md](CHANGELOG.md).

### Roadmap

**Shipped** scope is authoritative in **CHANGELOG.md**. **Forward** work is sequenced with [GitHub milestones and issues](https://github.com/kipyin/grace-notes/milestones) on [kipyin/grace-notes](https://github.com/kipyin/grace-notes). Milestones name **scope lanes**, not necessarily a new App Store **marketing** version every time. The app ships a **fixed marketing version per line** with a **monotonic build**; tags look like **`v{marketing}+{build}`**. Bump marketing only when opening the next line. Full convention: `.agents/skills/vc/SKILL.md` (**Versioning**).

## Terminology (contributors)

**Product English:** **entry** / **entries** (one calendar day’s journal on Today; type `JournalEntry` in code). The three structured groups are **Gratitudes**, **Needs**, and **People in Mind** (each holds up to five **lines**).

**Simplified Chinese (user-facing copy):** Prefer **记录** for day-level entry, **部分** for each structured group, and **条** for one slot/line in a section. Avoid **句子条** in completion or tutorial wording. Do not reintroduce **Abundance** or **满溢** in customer strings.

**Code vs UI labels:** Swift uses `JournalCompletionLevel` cases **`soil` … `bloom`**. On screen, the String Catalog maps those to the growth metaphor (**Soil → Sprout → Twig → Leaf → Bloom** in English; **静待播种 → 初露新芽 → 枝条初成 → 叶茂成形 → 花开有成** in zh-Hans). Legacy raw strings such as `empty`, `started`, `growing`, `balanced`, `full`, and `abundance` still decode into the current scale.

Avoid **chip** and **strip** in new user-facing or contributor prose; identifiers and UI tests may still use them.

- **Completion status** — Derived only from line counts in the three structured sections (`JournalCompletionLevel`). Reading notes and reflections do **not** change the status.
- **Top tier (`.bloom`)** — Five lines in each section (fifteen lines total), labeled **Bloom** / **花开有成** in the catalog. This is what **`JournalViewModel.completedToday`**, the **perfect** streak predicate, and first-run guided completion on Today use. Notes and reflections stay optional.

| Swift (`JournalCompletionLevel`) | English UI (localized value) | zh-Hans UI (localized value) | Legacy raw strings decoded from storage |
|----------------------------------|-----------------------------|------------------------------|----------------------------------------|
| `.soil` | Soil | 静待播种 | `soil`, `empty` |
| `.sprout` | Sprout | 初露新芽 | `sprout`, `started`, `seed` |
| `.twig` | Twig | 枝条初成 | `twig`, `growing` |
| `.leaf` | Leaf | 叶茂成形 | `leaf`, `balanced`, `ripening` |
| `.bloom` | Bloom | 花开有成 | `bloom`, `full`, `harvest`, `abundance` |

Main tabs: **Today** (journaling), **Past** (history and insights), **Settings**. Full-screen **App Tour** (`AppTourView` in code) can open from Today or Settings. Tour eligibility uses at least one line in each structured section (1/1/1) plus related flags (milestone copy uses **Sprout** / **初露新芽**, not the old “five cubed” naming).

## Requirements

- Xcode 26 or later (defaults in [`gracenotes-dev.toml`](gracenotes-dev.toml) use iPhone 17 Pro @ `OS=latest` and **iPhone SE (3rd generation) @ iOS 18.5** for the SE test/smoke matrix—override in TOML if your Xcode installs differ)
- iOS 17+ (app deployment target; see the Xcode project)

## Getting Started

1. Clone the repository.
2. Open `GraceNotes/GraceNotes.xcodeproj` in Xcode.
3. For code signing, select your development team in the project's Signing & Capabilities (if needed).
4. Select a simulator or device and run (⌘R). For a preview with sample journal entries, use the *GraceNotes (Demo)* scheme.

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
- `GraceNotes/GraceNotes/Features/Journal` - Journal UI, view models, and sharing
- `GraceNotes/GraceNotes/Data` - Models and persistence (SwiftData)
- `GraceNotes/GraceNotes/DesignSystem` - Theming and shared styling
- `GraceNotes/GraceNotes/Services` - Summarization and app-level business services

