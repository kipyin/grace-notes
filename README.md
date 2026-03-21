# Grace Notes

A journaling iOS app for daily gratitude, reflection, and people in mind.

## Overview

Grace Notes (`感恩记`) guides you through a simple daily rhythm: 5 gratitudes, 5 needs, 5 people in mind, reading notes, and space for what you're thinking and learning. The app offers a quiet, low-friction place for gratitude and reflection, with a gentle framing that feels welcoming rather than pushy.

## What's new in 0.5.0 (upcoming)

Target: **insight quality**—Review and weekly insights that better reflect your own entries, refined chip-label prompts for AI where used, and clearer feedback when a section is fully filled (`#40`, `#39`, `#11`). See `GraceNotes/docs/07-release-roadmap.md`.

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
- **First-run onboarding** – A short welcome flow introducing calm structure, review value, and low-pressure progress.
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

1. Set `CloudSummarizationAPIKey` in your local `Info.plist`.

Keep real keys out of git. The checked-in placeholder value (`YOUR_KEY_HERE`) causes automatic fallback to
on-device summarization.

## Project Structure

- `GraceNotes/GraceNotes/Application` - App entry point
- `GraceNotes/GraceNotes/Features/Journal` - Journal UI, view models, and sharing
- `GraceNotes/GraceNotes/Data` - Models and persistence (SwiftData)
- `GraceNotes/GraceNotes/DesignSystem` - Theming and shared styling
- `GraceNotes/GraceNotes/Services` - Summarization (Natural Language + optional cloud API for chip labels)

