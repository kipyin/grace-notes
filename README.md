# Grace Notes

A journaling iOS app for daily gratitude, reflection, and people in mind.

## Overview

Grace Notes (`感恩记`) guides you through a simple daily rhythm: 5 gratitudes, 5 needs, 5 people in mind, reading notes, and space for what you're thinking and learning. The app offers a quiet, low-friction place for gratitude and reflection, with a gentle framing that feels welcoming rather than pushy.

## What's new in 0.3.2

- First-launch startup now shows an immediate loading surface with calm rotating copy, reassurance, and retry-safe recovery instead of appearing frozen.
- Daily reminder setup now uses a dedicated drill-in flow with explicit permission prompting and clearer denied/off guidance.
- Reminder status now reflects live notification authorization plus pending schedule state rather than optimistic toggle intent.
- Input-pipeline stabilization fixes preserve typed text and keep keyboard momentum when committing entries and adding chips.

## Features

- **Daily journaling** - Today's entry with five gratitudes, five needs, five people in mind, reading notes, and reflections. Entries auto-create and save as you type.
- **Sequential input** – Type a full sentence, press Enter; the app summarizes it to a chip label. Tap a chip to edit its text. Supports 5 gratitudes, 5 needs, 5 people.
- **Review** – Browse past entries by month with weekly recurring-theme insights and continuity prompts.
- **Structured Review modes** – Switch between Insight and Timeline modes for cleaner weekly reflection and archive browsing.
- **Shareable cards** – Generate a formatted image of a day's entry and share via the iOS share sheet.
- **Reminders** – Optional daily notification to complete today's 5³.
- **Advanced review insights** – Optional AI-generated weekly reflection summary with deterministic on-device fallback.
- **Data trust controls** – iCloud sync setting plus full JSON export for backup and ownership.
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

