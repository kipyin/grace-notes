# Changelog

## [0.2.0] - 2026-03-16

### Added
- Chip delete: long-press chip to reveal delete button, tap x to remove
- Cloud summarization: optional OpenAI-compatible API with NL fallback
- Settings tab: toggle cloud summarization
- Chinese (Simplified, zh-Hans) localization

### Changed
- Section renames for app store: "People To Pray For" → "People in Mind", "Bible Notes" → "Reading Notes"
- Summarization protocol now async; ViewModel add/update flows use Task
- Sequential progress text uses localized format

### Fixed
- Faded chips: cap extracted keyword labels to show truncation gradient

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
