# Grace Notes

A journaling iOS app for daily gratitude, reflection, and people in mind.

## Overview

Grace Notes (`感恩记`) guides you through a simple daily rhythm: 5 gratitudes, 5 needs, 5 people in mind, reading notes, and space for what you're thinking and learning. The app offers a quiet, low-friction place for gratitude and reflection, with a gentle framing that feels welcoming rather than pushy.

## What's new in 0.5.0

Marketing version stays **0.5.0** across several TestFlight / App Store drops; each drop bumps **build** and git tag **`v0.5.0+{build}`**. GitHub milestone **0.5.2** names the scope lane for the work below, not a separate marketing version.

### Build 8 (Unreleased)

- **Journal onboarding** — Post-Seed journey (**C**) is driven by user state (completion level, `hasSeenPostSeedJourney`, guided journal), not app version gates; legacy `pending051*` keys migrate safely for installs mid-upgrade.
- **Today sequential entry (#102)** — Gratitudes, Needs, and People in mind take full sentences first, with inline edit on each saved line. See CHANGELOG.
- **Settings (#84)** — Section headers move to authored title case instead of forced all-caps list styling.
- **Review weekly rhythm (#115)** — **Reflection rhythm** in weekly insights uses a redesigned per-day column chart (horizontal scroll when needed); tap a day to open that day’s journal entry. See CHANGELOG.
- **Deterministic-only insights (#119)** — Cloud AI summarization and cloud review generation are removed; journal and Review insights now stay on-device (with optional iCloud sync).
- **Review insights (#40 / #80)** — Tracked on GitHub and in `GraceNotes/docs/07-release-roadmap.md` (**#80** may remain open for engine depth). See CHANGELOG for full bullets.

### Build 7 (2026-03-24)

- **Packaging** — Marketing **0.5.0**, build **7**, tag **`v0.5.0+7`**; Debug **dSYM**; shared **GraceNotes** scheme **Run** was **Release** in that build (later builds use **Debug** for Run; see CHANGELOG).
- **Onboarding** — Milestone cards that jump to Settings share one eligibility rule with the UI and re-check it when you tap; onboarding/iCloud continuity keys use shared constants (see CHANGELOG **Developer**). Post-Seed orientation sample Review preview matches real insights layout; welcome copy is slightly tighter.
- **Localization** — String Catalog **zh-Hans** polish and aligned **Save to Photos** permission wording for **感恩记**.
- **`AppInstructionLocale` + label grounding (#39)** — Instruction locale alignment, low-signal / grounding handling, unit tests (see CHANGELOG).
- **Product docs** — Roadmap separates **#40** vs **#80**; see `GraceNotes/docs/07-release-roadmap.md`.
- **UI tests** — Stable identifiers, English locale, relaunch-safe arguments, optional **`-grace-notes-reset-uitest-store`**, UI-test SwiftData session key (see CHANGELOG **Developer**).

### Foundation (2026-03-21)

- **Insight quality** — Review and weekly insights that better reflect your own entries: **#40**, **#80**, **#39**, **#11**.
- **First-run tutorial** — Dismissible hints toward **Started** and **Full** on today’s entry (`#60`).
- **Behavior-first onboarding** — Welcome, then guided first journal (Gratitude → Need → People → …); optional post-Seed journey; milestone suggestions (`#71`–`#75`).

See `GraceNotes/docs/07-release-roadmap.md`.

## What's new in 0.4.0

- **JSON import** — In Settings → Data & Privacy, import a Grace Notes export to merge or restore by calendar day (with a clear confirm step). Export remains available as before.
- **iCloud trust in Settings** — Storage and attention copy match how the app actually persists (including fallback and preference mismatch); when you need to open iOS Settings to fix the account, that action is easier to spot.
- **On-device short labels** on each saved line in the entry show a capped prefix of your own text (with ellipsis when needed).

## What's new in 0.3.5

- This patch is a maintenance release focused on release metadata and packaging consistency.
- Font resources now use deterministic build outputs during app packaging for more reliable release builds.

## Features

- **Daily journaling** - Today's entry with five gratitudes, five needs, five people in mind, reading notes, and reflections. Entries auto-create and save as you type.
  - **Sequential input** – Type a full sentence, press Enter; your full line stays easy to read on Today. Tap a line to edit inline. Each section holds up to five lines (5 gratitudes, 5 needs, 5 people).
- **Review** – Browse past entries by month with weekly recurring-theme insights and continuity prompts.
- **Weekly insights** – Insights-first Review with a scrollable **Reflection rhythm** chart (tap a day that has a saved entry to open that day’s journal).
- **Shareable cards** – Generate a formatted image of a day's entry and share via the iOS share sheet.
- **Reminders** – Optional daily notification to complete today’s entry (including a fully filled structured entry when you want it).
- **Advanced review insights** – Deterministic weekly reflection summary generated on-device.
- **Data trust controls** – private-by-default storage plus JSON export and import for backup and ownership.
- **First-run onboarding** – A minimal welcome followed by a guided first journal path on Today, with milestone-based opt-in suggestions for reminders and iCloud.
- **Habit support** – Streak plus tiered completion states (quick check-in, standard reflection, structured entry fully filled) to reduce all-or-nothing pressure.

## Terminology (contributors)

Official product language: **entry** / **entries** (what the user writes; one **journal entry** per calendar day on Today, type `JournalEntry` in code). Avoid **chip** and **strip** in new user-facing or contributor-facing copy—legacy code and tests may still use those words in identifiers (e.g. UI-test element names).

- **Completion status** — How complete the *structured* part of an entry is (**Gratitudes**, **Needs**, **People in mind**: up to five **lines** per section). Represented by `JournalCompletionLevel`. Reading notes and reflections are part of the same entry but do not change completion status.
- **Abundance** / **full rhythm** — User-facing term for when the entry has all fifteen structured lines filled **and** non-empty reading notes and reflections (`hasAbundanceRhythm` in code). Still distinct from **Full** completion status alone (structured sections only—see `completedToday` / `criteriaMet` on `JournalViewModel` / `JournalEntry`).

| Completion status (en) | Swift (`JournalCompletionLevel`) | Legacy raw strings still decoded from storage |
|------------------------|----------------------------------|-----------------------------------------------|
| Empty | `.empty` | `empty`, `soil` |
| Started | `.started` | `started`, `seed` |
| Growing | `.growing` | `growing` |
| Balanced | `.balanced` | `balanced`, `ripening` |
| Full | `.full` | `full`, `harvest`, `abundance` |

Main tabs: **Today** (journaling), **Review** (history and insights), **Settings**. The full-screen onboarding continuation is **`PostSeedJourney`** / **App tour** in code and settings; eligibility for **Started** is at least one line in each structured section (1/1/1), plus related flags—not the old “five cubed” naming.

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

