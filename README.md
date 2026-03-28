# Grace Notes

A journaling iOS app for daily gratitude, reflection, and people in mind.

## Overview

Grace Notes (`感恩记`) guides you through a simple daily rhythm: 5 gratitudes, 5 needs, 5 people in mind, reading notes, and space for what you're thinking and learning. The app offers a quiet, low-friction place for gratitude and reflection, with a gentle framing that feels welcoming rather than pushy.

## Release notes

Version history, per-build notes, and git tag shape (**`v{marketing}+{build}`**, e.g. **`v0.5.0+8`**) are maintained only in [CHANGELOG.md](CHANGELOG.md). Scope and sequencing: [GraceNotes/docs/07-release-roadmap.md](GraceNotes/docs/07-release-roadmap.md).

## Features

- **Daily journaling** - Today's entry with five gratitudes, five needs, five people in mind, reading notes, and reflections. Entries auto-create and save as you type.
  - **Sequential input** – Type a full sentence, press Enter; your full line stays easy to read on Today. Tap a line to edit inline. Each section holds up to five lines (5 gratitudes, 5 needs, 5 people).
- **Past** – Middle tab: browse past entries by month with weekly recurring-theme insights and continuity prompts.
- **Weekly insights** – Insights-first layout on **Past** with a scrollable **Reflection rhythm** chart (tap a day that has a saved entry to open that day’s journal).
- **Shareable cards** – Generate a formatted image of a day's entry and share via the iOS share sheet.
- **Reminders** – Optional daily notification to complete today’s entry (including a fully filled structured entry when you want it).
- **Advanced weekly insights** – Deterministic weekly reflection summary generated on-device.
- **Data trust controls** – private-by-default storage plus JSON export and import for backup and ownership.
- **First-run onboarding** – A minimal welcome followed by a guided first journal path on Today, with milestone-based opt-in suggestions for reminders and iCloud.
- **Habit support** – Streak plus tiered completion on the structured sections; **perfect** streak days match a full fifteen-line grid (optional reading notes and reflections do not gate the perfect count).

## Terminology (contributors)

**Product English:** **entry** / **entries** (one calendar day’s journal on Today; type `JournalEntry` in code). The three structured groups are **Gratitudes**, **Needs**, and **People in mind** (each holds up to five **lines**).

**Simplified Chinese (user-facing copy):** Prefer **记录** for day-level entry, **部分** for each structured group, and **条** for one slot/line in a section. Avoid **句子条** in completion or tutorial wording. Do not reintroduce **Abundance** or **满溢** in customer strings.

**Code vs UI labels:** Swift uses `JournalCompletionLevel` cases **`empty` … `full`**. On screen, the String Catalog maps those to the growth metaphor (**Soil → Sprout → Twig → Leaf → Bloom** in English; **静待播种 → 初露新芽 → 枝条初成 → 叶茂成形 → 花开有成** in zh-Hans). `String(localized:)` keys in code are still the enum-style words **Empty**, **Started**, **Growing**, **Balanced**, **Full**; localized **values** are the metaphor labels above.

Avoid **chip** and **strip** in new user-facing or contributor prose; identifiers and UI tests may still use them.

- **Completion status** — Derived only from line counts in the three structured sections (`JournalCompletionLevel`). Reading notes and reflections do **not** change the status.
- **Top tier (`.full`)** — Five lines in each section (fifteen lines total), labeled **Bloom** / **花开有成** in the catalog. This is what **`JournalViewModel.completedToday`**, the **perfect** streak predicate, and first-run guided completion on Today use. Notes and reflections stay optional.

| Swift (`JournalCompletionLevel`) | English UI (localized value) | zh-Hans UI (localized value) | Legacy raw strings decoded from storage |
|----------------------------------|-----------------------------|------------------------------|----------------------------------------|
| `.empty` | Soil | 静待播种 | `empty`, `soil` |
| `.started` | Sprout | 初露新芽 | `started`, `seed` |
| `.growing` | Twig | 枝条初成 | `growing` |
| `.balanced` | Leaf | 叶茂成形 | `balanced`, `ripening` |
| `.full` | Bloom | 花开有成 | `full`, `harvest`, `abundance` |

Main tabs: **Today** (journaling), **Past** (history and insights), **Settings**. Full-screen onboarding continuation: **`PostSeedJourney`** / **App tour** in code and Settings. **Post-Seed** eligibility uses at least one line in each structured section (1/1/1) plus related flags (milestone copy uses **Sprout** / **初露新芽**, not the old “five cubed” naming).

## Requirements

- Xcode 26 or later (default `make` destinations use iPhone 17 Pro @ iOS 26.3 and iPhone XR @ iOS 17.5; use an older Xcode only if you override `DESTINATION` and `TEST_DESTINATION_MATRIX` to match what that Xcode installs)
- iOS 17+ (app deployment target; see the Xcode project)

## Getting Started

1. Clone the repository.
2. Open `GraceNotes/GraceNotes.xcodeproj` in Xcode.
3. For code signing, select your development team in the project's Signing & Capabilities (if needed).
4. Select a simulator or device and run (⌘R). For a preview with sample journal entries, use the *GraceNotes (Demo)* scheme.

## Automation

Use the root `Makefile` for common local workflows (tests use the **GraceNotes** scheme only; the **GraceNotes (Demo)** scheme stays in Xcode for ⌘R with sample data):

- `make lint` – Run SwiftLint checks (requires `swiftlint` on your PATH).
- `make build` – Build the app (requires macOS + Xcode).
- `make test` – Run unit + UI tests for **GraceNotes** on `DESTINATION` (resolved via `Scripts/simulator_destination.py`).
- `make test-all` – Reset simulators, then `make test` (reduces flaky simulator state).
- `make test-matrix` – Run **GraceNotes** tests across `TEST_DESTINATION_MATRIX` (default: iPhone XR @ iOS 17.5 and iPhone 17 Pro @ iOS 26.3).
- `make validate-destination` / `make validate-test-matrix` – Check that simulator names and OS versions exist before running tests.
- `make list-simulator-destinations` – List installed `platform=iOS Simulator,...` strings.
- `make ci` – Lint + `test-all`.
- `make ci-matrix` – Lint + `test-matrix`.

Examples:

```bash
make test DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
make test-matrix TEST_DESTINATION_MATRIX='iPhone SE (3rd generation)@18.5;iPhone 17 Pro@26.2'
```

On iOS 17 simulators, `make` applies targeted `-skip-testing` flags for a few hosted SwiftData suites that crash before assertions; see `Makefile` (`LEGACY_RUNTIME_SKIP_FLAGS`).

If `make lint` reports that SwiftLint is missing, install it with Homebrew:

```bash
brew install swiftlint
```

Note: `make test-all` resets simulators (wipes simulator state) to reduce flaky preflight failures.

## CI (GitHub Actions)

Workflows: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (lint, build, tests) and [`.github/workflows/codeql.yml`](.github/workflows/codeql.yml) (CodeQL Swift). **CodeQL** runs **daily** at **20:00 UTC** (**04:00 UTC+8**). The CodeQL workflow stores the last successfully analyzed `main` commit in **`actions/cache`** (a new cache entry per commit so the marker can advance); scheduled runs **skip** the traced macOS build when that marker matches the current `main` tip. A cache **miss** or **eviction** still runs the full scan. **Run workflow** (`workflow_dispatch`) on CodeQL always performs a full analysis.

**CI workflow (`ci.yml`).** Simulator steps use **`make`** (`ci-build`, `ci-full`, `ci-pr-full-ci`; `ci-merge-queue` is an alias for `ci-full` in the [`Makefile`](Makefile)) so destinations match `Scripts/simulator_destination.py` resolution.

**Why not both `push` and `pull_request` on every branch?** A push to a PR branch used to trigger *two* workflow runs (push + pull_request), which was noisy. The workflow now uses **`pull_request` only for PRs targeting `main`**, and **`push` only for the `main` branch** (post-merge build). Feature branches without a PR do not run CI until you open one.

| When | What runs |
|------|-----------|
| **Pull request → `main`** | **Lint & build (iPhone 17 Pro)** — `make lint` then `make ci-build`. **`CI_SIMULATOR_PRO`** is **iPhone 17 Pro @ iOS 26.2** (hosted-runner compromise; SE (3rd generation) smoke remains iOS 18.5). |
| **Push → `main`** | **Main push — lint, test, UI smoke** — `make ci-full`: `make lint`, `make test` on **iPhone 17 Pro** (`CI_SIMULATOR_PRO`), then `make test-ui-smoke` on **iPhone SE (3rd generation)** (`CI_SIMULATOR_XR`). Smoke: `GraceNotesSmokeUITests.testSmokeLaunch`. Skipped when the push SHA is the **`merge_commit_sha`** of a PR merged into **`main`** and that PR is labeled **`no-ci`** (avoids unrelated PRs on the same commit). |
| **Pull request + label `full-ci`** | **PR full-ci — lint, test, UI smoke** — `make ci-pr-full-ci` (same as `ci-full`). Re-runs on new commits while the label is present. |

The **`full-ci`** and **`no-ci`** labels must exist in the GitHub repo (Issues → Labels). Adjust **`CI_SIMULATOR_PRO`** / **`CI_SIMULATOR_XR`** in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and [`Makefile`](Makefile) if Apple or runner images change.

**Branch protection:** Configure required status checks for your merge policy—for example **Lint & build (iPhone 17 Pro)** on PRs, and optionally **Main push — lint, test, UI smoke** after merges. **Lint & build** runs on the pull-request SHA only; add **PR full-ci** (label) when you need the full suite before merge. If you used GitHub merge queue before, remove merge queue and any obsolete required checks in **Settings → Branches**.

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

