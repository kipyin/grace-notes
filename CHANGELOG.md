# Changelog

## [0.2.2] - Unreleased

### Added
- (none)

### Changed
- Chip switching performance: tapping between chips (Gratitudes, Needs, People) switches immediately; summarization runs in background with interim 20-char label; no update when text unchanged
- Settings: cloud summarization toggle defaults to OFF (aligns with SummarizerProvider; first launch no longer shows ON when NL is used)
- JournalViewModel migrated to `@Observable` (iOS 17+); JournalScreen uses `@State` instead of `@StateObject`

### Fixed
- Journal share sheet: `JournalShareRenderer.renderImage` correctly isolated to main actor
- JournalScreen extension: Swift access control fix so share sheet can access view state

### Developer
- SwiftLint config (`.swiftlint.yml`): type_body_length, cyclomatic_complexity, identifier_name, line_length
- Code quality: identifier renames (vm→viewModel, c→container, t→tag, r/g/b→red/green/blue); line-length fixes; static_over_final_class in UI test launch
- JournalScreen refactor: extract subviews and chip handlers; reduce chipTapped complexity
- Background summarization Task (runs on main actor); @MainActor annotations for concurrency
- Tests: SummarizerProvider, CloudSummarizer, completedToday, slot limit; JournalViewModelTests updates
- Docs: code quality analysis plan, implementation path, viewing chips performance plan
- CI: simulator id-only destination; unit-test-only execution; test target path fixes; TimeZone unwrap in test setUp

## [0.2.1] - 2026-03-16

### Changed
- Chip deletion UX: long-press to delete with optional confirmation (Settings: "Confirm chip deletion"); removed deletion mode, wiggle, minus badge, double-tap
- Journal screen dismisses keyboard immediately when scrolling

### Fixed
- (none)

### Developer
- ApiSecrets doc comment clarity
- Remove unused JournalViewModel.summarize; remove WiggleModifier

## [0.2.0] - 2026-03-16

### Added
- Chip delete: long-press chip to reveal delete button, tap x to remove
- Cloud summarization: optional OpenAI-compatible API with NL fallback
- Settings tab: toggle cloud summarization
- Chinese (Simplified, zh-Hans) localization
- Toast notification when photo is saved to library via share sheet
- Section-tailored summarization prompts (gratitude/need/person-specific; Chinese stop words and NLLanguage)

### Changed
- Section renames for app store: "People To Pray For" → "People in Mind", "Bible Notes" → "Reading Notes"
- Chip deletion UX: section-level deletion mode with wobble animation, long-press or double-tap to enter, minus badge, Done button, auto-exit when last chip deleted
- Summarization protocol now async; ViewModel add/update flows use Task
- Sequential progress text uses localized format

### Fixed
- Faded chips: cap extracted keyword labels to show truncation gradient
- Chip content mix-up after deletion (stable JournalItem id for SwiftUI ForEach)

### Developer
- Calendar view exploration doc (defer implementation to 0.3.0)

## [0.1.1] - 2026-03-16

### Added
- Save to Photos option in share sheet for journal cards
- "Add new" chip button in sequential sections (Gratitudes, Needs, People)
- Release 0.2.0 planning doc

### Changed
- iOS deployment target lowered from 18.6 to 17.0 for broader device support
- Asset catalog moved into app target folder

### Fixed
- NL summarizer now prefers named entities (people, places, orgs) for chip labels

## [0.1.0] - 2026-03-16

### Added
- `JournalItem` model with fullText, chipLabel, and isTruncated
- `Summarizer` protocol and `NaturalLanguageSummarizer` for NL-based chip labels
- `ChipView` and `SequentialSectionView` for sequential input UX
- Sequential input flow: single field per section, Enter to add chip, tap chip to edit
- First-N-words fallback when NL extraction returns empty

### Changed
- `JournalEntry` gratitudes/needs/people from `[String]` to `[JournalItem]`
- Journal screen layout: Form → ScrollView with sequential sections
- History screen uses `entry.isComplete` (centralized completion logic)
- Tab bar background uses Warm Paper theme

### Fixed
- (none in this release)

### Developer
- `MockSummarizer` for ViewModel testing
- NaturalLanguageSummarizer unit tests
