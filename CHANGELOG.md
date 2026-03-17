# Changelog

## [0.2.3] - Unreleased

### Added
- Daily local reminder support in Settings with a reminder toggle, time picker, and persisted reminder preferences
- Reminder scheduling service (`ReminderScheduler`) with focused reminder settings constants (`ReminderSettings`)
- Streak tracking with derived `basic` and `perfect` streaks computed from existing `JournalEntry` data
- Journal header streak display showing current Basic and Perfect streak values
- New unit tests for reminder scheduling behavior and streak calculation edge cases
- Product strategy implementation plan doc (`PRODUCT_STRATEGY_IMPLEMENTATION_PLAN_2026-03-17.md`)
- Weekly review insights domain with deterministic recurring-theme generation
- Cloud AI weekly review insights generator with provider fallback to deterministic insights
- Review tab summary card showing weekly narrative, recurring themes, resurfacing, and continuity prompt
- Data export service for full journal JSON archive from Settings
- iCloud/CloudKit capability wiring (`FiveCubedMoments.entitlements`) and cloud-capable SwiftData configuration path
- First-run onboarding screen introducing structure, review value, and low-pressure progress
- Sprint-ready planning doc for review + onboarding execution (`review-onboarding-sprint-plan-2026-03-17.md`)

### Changed
- JournalViewModel now computes and exposes a `streakSummary` whenever entries are loaded/saved
- Basic streak logic now counts only meaningful journal activity (not auto-created blank entries)
- Sequential section add chip `(+)` now stays hidden when all five entries are filled, including while editing an existing chip
- Progress footer now always uses plain count text (for example, `2 of 5`) without the `- editing` suffix
- Tab/navigation copy updated from **History** to **Review**
- Settings now include AI review-insights toggle, iCloud sync preference, and data trust/privacy messaging
- Review screen now offers segmented **Insights** and **Timeline** modes for less cluttered navigation
- Journal completion now supports tiered levels (`Quick check-in`, `Standard reflection`, `Full 5³`) surfaced in Today + Review UI
- Review insights now refresh on entry updates (`updatedAt`) and only auto-fetch in Insights mode
- Settings JSON export now runs asynchronously with in-app progress feedback (reduced main-thread blocking)
- Cloud review request now includes explicit response constraints (`max_tokens`, `temperature`)

### Fixed
- Review-insight fallback week boundaries now match week-of-year logic used by deterministic/cloud generators
- Review screen naming now matches product terminology in code (`ReviewScreen`)
- Cloud review payloads are now sanitized/clamped (message length, theme counts, non-empty positive themes)
- Shared iCloud sync defaults key now references a single source (`PersistenceController.iCloudSyncEnabledKey`)

### Developer
- Added `StreakCalculator` service and `StreakSummary` value type for derived, read-time streak metrics
- Added reminder and streak test coverage for permission flows, time scheduling, skipped-day breaks, and day-boundary normalization
- Removed unused localization key `"%d of %d — editing"`
- Added tests for deterministic review insights, cloud review insights decoding, provider fallback behavior, and JSON export payload integrity
- Added completion-level test coverage for Journal model and ViewModel states
- Improved test naming consistency for deterministic review insights suite
- Strengthened cloud review tests with meaningful thrown-error assertions and payload clamping checks

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
