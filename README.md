# Grace Notes

A journaling iOS app for daily gratitude, reflection, and people in mind.

## Overview

Grace Notes (`感恩记`) guides you through a simple daily rhythm: 5 gratitudes, 5 needs, 5 people in mind, reading notes, and space for what you're thinking and learning. The app offers a quiet, low-friction place for gratitude and reflection, with a gentle framing that feels welcoming rather than pushy.

## What's new in 0.5.0 (2026-03-24)

- **Packaging** — Ships as marketing **0.5.0**, build **7** (git tag **v0.5.0+7**). Debug builds emit **dSYM** for richer crash logs, and the shared **GraceNotes** scheme’s Run action uses the **Release** configuration (verify this matches your day-to-day workflow in Xcode).
- **Onboarding** — Milestone cards that jump to Settings share one eligibility rule with the UI and re-check it when you tap; onboarding/iCloud continuity keys use shared constants (see CHANGELOG **Developer** for detail). Post-Seed orientation sample Review preview matches real insights layout; welcome copy is slightly tighter.
- **Localization** — String Catalog **zh-Hans** polish (including onboarding and Abundance-related copy) and aligned **Save to Photos** permission wording for **感恩记**.
- **Cloud chips (#39)** — Chip cloud summarization picks instruction language the same way as Review (`AppInstructionLocale`), tightens low-signal and ungrounded-output handling, and adds focused unit tests (see CHANGELOG).
- **Product docs** — Review insight roadmap now separates **#40** (insight-first presentation) from **#80** (deeper insight engine work); see `GraceNotes/docs/07-release-roadmap.md`.
- **UI tests** — Journal UI tests use stable chip and add-row identifiers, English locale, relaunch-safe launch arguments, optional **`-grace-notes-reset-uitest-store`** between cases, and a UI-test SwiftData session key so data survives `terminate()` + `launch()` when appropriate (see CHANGELOG **Developer**).

## What's new in 0.5.0

- **Insight quality** — Review and weekly insights that better reflect your own entries: presentation work as **#40**, deeper generation iteration as **#80**; refined chip-label prompts for AI where used (**#39**); clearer feedback when a section is fully filled (**#11**).
- **First-run tutorial** — Dismissible hints on Today toward Seed and Harvest, with one-time congratulations when you first reach those tiers (`#60`).
- **Behavior-first onboarding** — First launch now opens with a minimal welcome, then guides your first journal on Today one step at a time (Gratitude → Need → People → Seed / Ripening / Harvest / Abundance). The first time you reach Seed, an optional skippable full-screen intro can appear; afterward, milestone suggestions for reminders, AI, and iCloud stay contextual (`#71`, `#72`, `#73`, `#74`, `#75`).

See `GraceNotes/docs/07-release-roadmap.md`.

## What's new in 0.4.0

- **JSON import** — In Settings → Data & Privacy, import a Grace Notes export to merge or restore by calendar day (with a clear confirm step). Export remains available as before.
- **iCloud trust in Settings** — Storage and attention copy match how the app actually persists (including fallback and preference mismatch); when you need to open iOS Settings to fix the account, that action is easier to spot.
- **AI row** — When cloud AI is on, you get inline connection status, optional reachability check, and a Reminders-style layout (toggle + tappable status).
- **On-device chip labels** show a capped prefix of your own text (with ellipsis when needed); cloud summarization is unchanged.

## What's new in 0.3.5

- This patch is a maintenance release focused on release metadata and packaging consistency.
- Font resources now use deterministic build outputs during app packaging for more reliable release builds.

## Features

- **Daily journaling** - Today's entry with five gratitudes, five needs, five people in mind, reading notes, and reflections. Entries auto-create and save as you type.
- **Sequential input** – Type a full sentence, press Enter; the app summarizes it to a chip label. Tap a chip to edit its text. Supports 5 gratitudes, 5 needs, 5 people.
- **Review** – Browse past entries by month with weekly recurring-theme insights and continuity prompts.
- **Structured Review modes** – Switch between Insight and Timeline modes for cleaner weekly reflection and archive browsing.
- **Shareable cards** – Generate a formatted image of a day's entry and share via the iOS share sheet.
- **Reminders** – Optional daily notification to complete today's 5³.
- **Advanced review insights** – Optional AI-generated weekly reflection summary with deterministic on-device fallback.
- **Data trust controls** – private-by-default storage plus JSON export and import for backup and ownership.
- **First-run onboarding** – A minimal welcome followed by a guided first journal path on Today, with milestone-based opt-in suggestions for reminders, AI, and iCloud.
- **Habit support** – Streak plus tiered completion states (Quick, Standard, Full 5³) to reduce all-or-nothing pressure.

## Requirements

- Xcode 15 or later
- iOS 17+

## Getting Started

1. Clone the repository.
2. Open `GraceNotes/GraceNotes.xcodeproj` in Xcode.
3. For code signing, select your development team in the project's Signing & Capabilities (if needed).
4. Select a simulator or device and run (⌘R). For a preview with sample journal entries, use the *GraceNotes (Demo)* scheme.

## Automation

Use the root `Makefile` for common local workflows:

- `make lint` – Run SwiftLint checks (requires `swiftlint` on your PATH).
- `make build` – Build the app (requires macOS + Xcode).
- `make test` – Run tests for the default scheme (requires macOS + Xcode + iOS Simulator).
- `make test-demo` – Reset/warm simulators, then run tests for the demo scheme.
- `make test-all` – Reset simulators between default and demo test runs.
- `make ci` – Run lint and tests for both schemes.

If `make lint` reports that SwiftLint is missing, install it with Homebrew:

```bash
brew install swiftlint
```

Note: `make test-demo` and `make test-all` intentionally reset simulators to reduce flaky preflight failures. This wipes simulator state for deterministic test runs.

## Tech Stack

- Swift and SwiftUI
- SwiftData for local persistence
- Natural Language framework for summarization
- CloudKit-ready sync configuration for SwiftData
- MVVM-style architecture

## Cloud Summarization Key Setup (Optional)

Cloud summarization is optional and defaults to off. To enable it safely:

1. Put your key in **gitignored** `GraceNotes/DeveloperSettings.local.xcconfig` (see `DeveloperSettings.local.xcconfig.example`). Committed `DeveloperSettings.xcconfig` supplies `GRACE_NOTES_CLOUD_API_KEY`, which `Info.plist` passes through as `CloudSummarizationAPIKey`.

Keep real keys out of git. A missing or placeholder key causes automatic fallback to on-device summarization.

## Project Structure

- `GraceNotes/GraceNotes/Application` - App entry point
- `GraceNotes/GraceNotes/Features/Journal` - Journal UI, view models, and sharing
- `GraceNotes/GraceNotes/Data` - Models and persistence (SwiftData)
- `GraceNotes/GraceNotes/DesignSystem` - Theming and shared styling
- `GraceNotes/GraceNotes/Services` - Summarization (Natural Language + optional cloud API for chip labels)

