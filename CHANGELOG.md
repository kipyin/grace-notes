# Changelog

## [0.5.0]

Marketing version **0.5.0** ships as successive **builds** (TestFlight / App Store); git tags **`v0.5.0+{build}`**. GitHub milestones **0.5.2**, **0.5.3**, etc. name **scope lanes**, not separate marketing versions — see `GraceNotes/docs/07-release-roadmap.md`. Older docs or issues may still mention interim labels (**0.5.1**, **0.5.2**); **ship truth** is **0.5.0 + build** below.

### Build 8 — 2026-03-28

Work tracked toward milestone **0.5.2** (Settings cohesion and insight follow-through); shipped as marketing **0.5.0** / bundle **8** (git tag **`v0.5.0+8`**).

### Changed

- Past: **Search** (en / zh-Hans) labels the Past tab inline field — results and behavior unchanged; clearing the query restores insights cards. The dismiss control sits **outside** the search pill (trailing, 44pt target), clears non-empty text, and dismisses the keyboard with **Today**-aligned snappy layout animation (respects Reduce Motion). While the search field is focused, list scrolling does not dismiss the keyboard. **zh-Hans** Past search copy refined (`Localizable.xcstrings`).
- Journal: removed the extra **Abundance** / full-rhythm tier. **Harvest** (all fifteen structured lines) is now the top state for **perfect** streaks, **`completedToday`**, and first-run onboarding; reading notes and reflections are optional. Legacy decode still maps raw **`abundance`** → **`.full`** where older data or APIs use that string (`JournalCompletionLevel`, weekly mix JSON).
- Copy / localization (**#128**): completion surfaces use the **Soil → Bloom** English set and locked **zh-Hans** status labels (静待播种 → 花开有成); contributor glossary (**记录** / **部分** / **条**) in completion-facing strings; string catalog scrubbed for user-facing **Abundance**, **满溢**, cloud/AI product framing, and em dash in customer copy where the issue checklist applies.
- **Data export:** JSON share filenames now use the prefix **`grace-notes-export-`** instead of `five-cubed-journal-export-`. Automation or scripts that match the old basename need updating (#133 / #136).
- Review > Insights: weekly **Reflection rhythm** uses a redesigned column visualization (completion tier per day, horizontal scroll with edge feathering when the week is wider than the card); only days with a **saved journal row** navigate to `JournalScreen`—empty history slots stay visual-only with a distinct VoiceOver hint (#115).
- Review rhythm day labels format with `DateFormatter` configured from the passed `Calendar` (locale and time zone) (`ReviewRhythmFormatting`).
- Journal: **Today** sequential sections (**Gratitudes**, **Needs**, **People in mind**) show submitted lines as **sentence strips** with inline edit (full sentence first; chip labels stay secondary for aggregation). Inline empty-space dismiss uses a clearer scroll backdrop; navigation-bar taps use bar-frame hit testing. Chip add/tap orchestration goes through `JournalChipInteractionCoordinator` (#102).
- Review > Insights: single read-only **Source** badge (replacing twin pills that read like a control); insights UI copy framed for on-device digest only (**#83**, **#119**).
- Settings: section headers use authored title case instead of all-caps list header styling (#84).
- Journal: middle tab label **Review** → **Past** (en / zh-Hans); onboarding copy that directed users to the **Review** tab now names **Past** (`Localizable.xcstrings`, `GraceNotesApp`, `ReviewScreen`, `JournalUITests`) (#130).
- Review: **Reflection rhythm** uses **Today** instead of a weekday abbreviation for the current calendar day’s column (`ReviewRhythmFormatting`, unit tests) (#132).
- Review > Insights: thin-week **Write today's reflection** control switches to **Today**; flatter insights column (inset panels only, no outer summary shell); **This week** title row shows the week date range; read-only on-device source labeling; unified semibold panel titles; system **Insights** / **Timeline** segmented control (Liquid Glass on iOS 26+) with `ReviewModePicker` id preserved (#85).
- Review insights engine: weekly **reflection day count** and **narrative summary** now treat non-empty reading notes or reflections as signal (even when chip completion is still **Empty**), so sparse-week and narrative behavior match long-form journaling (#85).
- Review insights: continue #40 / #80 follow-through in the **0.5.2** milestone lane on GitHub (**#80** may remain open for engine depth).

### Fixed

- Review: **Reflection rhythm** horizontal strip pins to the trailing edge on first layout when the week is wider than the card, so the current day is not left under the trailing edge fade (`UIScrollView` KVO + `contentOffset`; issue #127).

### Developer

- Tests: SwiftData unit tests use in-memory isolation (`SwiftDataTestIsolation`) so `JournalViewModel*`, `JournalRepository`, import, and `PersistenceRuntimeSnapshot` suites run on the iOS Simulator instead of skipping; `JournalViewModel` supports a shorter autosave debounce for UI tests (`-grace-notes-uitest-short-autosave` or `autosaveDebounceMilliseconds` in tests).
- Journal: `JournalTodayOrientationPolicy` centralizes Today-only post-Seed presentation (delegating to `PostSeedJourneyTrigger`) and Seed unlock toast suppression; `JournalScreen` consumes it. Product matrix and dual-completion behavior live in code and tests (`JournalTodayOrientationPolicy`, `JournalTodayOrientationPolicyTests`).
- Journal: post-Seed journey (**C**) is **version-free**—eligibility uses `hasSeenPostSeedJourney`, Today completion **≥ Seed**, and `completedGuidedJournal` (skip congratulations only). Removed `OrientationReleaseGate` and launch-time cohort flags; `JournalOnboardingProgress.migrateLegacyPostSeedOrientationFlagsIfNeeded` normalizes legacy `pending051UpgradeOrientation` into guided/branch state, clears the upgrade key, and keeps `legacy051GuidedBranchResolution` until Today runs `resolvePending051GuidedJournalBranch`. Settings **App tour** sets `hasSeenPostSeedJourney` on finish without completing guided journal and skips the Seed congratulations page when guided journal is already complete. `AppLaunchVersionTracker` still records last marketing/bundle only.
- Journal (Abundance removal): `JournalEntry` drops `hasAbundanceRhythm` / `criteriaMet`; `StreakCalculator` “perfect” uses `hasHarvestChips`; `JournalOnboardingFlowEvaluator` drops the post-harvest notes gate; `JournalOnboardingContext` no longer carries reading-notes fields for onboarding. Unit tests updated (`StreakCalculatorTests`, `JournalOnboardingFlowEvaluatorTests`, `JournalCompletionLevelTests`, `JournalViewModelCompletionAndLimitsTests`).
- Versioning: Grace Notes app **marketing version** stays **0.5.0** for this lane; **bundle** (`CURRENT_PROJECT_VERSION`) **8** (increment build under the minor for faster TestFlight review; build **7** was the previous ship).
- Contributor workflow: removed `GraceNotes/docs/agent-log/`, `Scripts/validate-agent-log.sh`, and `make verify-agent-log*`; use GitHub issues/PRs and `AGENTS.md` for coordination.
- Journal architecture: `JournalExportPayload` / `JournalExportSnapshotSource`, `JournalStreakSummaryRefresher`, and `JournalChipLabelSummarizationCoordinator` split from `JournalViewModel` responsibilities; behavior unchanged (#90).
- UI tests: Today journal inputs use `UITextView` (`InlineSentenceEditorField`); `JournalUITests` query **TextView** for composer and strip editor identifiers. `test_todayScreen_submitKeepsKeyboardAvailableForNextEntry` expects the keyboard after the strip appears and the user opens the composer for the next line (#102).
- Review: `ReviewDayActivity.hasPersistedEntry` gates rhythm-column drill-in so empty history days do not create journal rows; `JournalUITests.test_reviewScreen_rhythmDrillInOpensJournalWithShare` covers Past tab → rhythm column → journal (#115).
- Xcode: shared **GraceNotes** scheme **Run** (**LaunchAction**) uses **Debug** so ⌘R matches typical local debugging; bundle **7** notes still describe **Run** on **Release** at that ship cut (#102 review).

### Build 7 — 2026-03-24

Packaging, upgrade orientation, localization, and stability under marketing **0.5.0** / bundle **7** (git tag **`v0.5.0+7`**; replaces interim **0.5.1** / bundle **3** labeling).

### Added
- Journal: **one-time upgrade orientation** on the first launch of **0.5.0** build **7** after an older marketing version or an older **0.5.0** build. Users still below **Seed** on Today keep the full guided chip path; users **at or above Seed** see the post-Seed settings-oriented journey **without** the Seed congratulations page. Launch tracks marketing and bundle (`lastLaunchedMarketingVersion`, `lastLaunchedBundleVersion`); migration into `completedGuidedJournal` is deferred until Today’s completion level is known for that cohort.

### Changed
- Copy: user-facing **en** / **zh-Hans** avoids **chip** and **journal** in favor of product language (Grace Notes, short labels, spots, entries, and the three section names). Updated onboarding locks, completion hints, startup and save errors, Data & Privacy, Review timeline a11y, AI suggestions, and **Save to Photos** permission text (`Localizable.xcstrings`, `Info.plist` / `InfoPlist.xcstrings`, matching `String(localized:)` keys in app sources).
- Settings **Cloud AI** toggle and a11y strings use American English **Summarize** (not *Summarise*). `AGENTS.md` and Translator skill call out **American English** for user-facing English strings.
- String Catalog: additional **en** / **zh-Hans** entries for previously empty keys; Simplified Chinese copy refined for onboarding, Abundance meaning, and AI onboarding lines. Info.plist **Save to Photos** usage description uses **感恩记** and consistent 你/你的 tone (`zh-Hans`).
- Cloud chip summarization uses shared **`AppInstructionLocale`** for instruction language (aligned with Review insights), with optional `ChipCloudPromptLanguage` for tests; skips obvious low-signal keyboard mash before the network call; drops model output that fails grounding or reads as unrelated generic filler (#39).
- Review cloud insights `.automatic` prompt language now resolves through **`AppInstructionLocale`** instead of ad hoc bundle checks (#39).
- Journal: post-Seed orientation journey sample **Review** preview uses the same observation + muted follow-up layout as weekly insights (new string catalog keys in **en** / **zh-Hans**); first-run onboarding welcome drops a redundant subtitle line.

### Fixed
- iOS 17: startup no longer crashes when applying global UIKit appearance; `AppInterfaceAppearance.configure()` runs from `UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:)` instead of `App` `init`.
- Dynamic Type: tab bar item titles cap at **Large** text size so labels no longer overlap icons when the user chooses very large system text (#76). Navigation bar titles and bar-button labels cap at **Extra Extra Large** to reduce cramped chrome while keeping editorial body copy unchanged.
- Journal: with cloud summarization on, chip text that already fits the on-chip display budget (≤10 display units, same Han/Latin rules as truncation) no longer calls the cloud summarizer (#69).

### Developer

- Product docs: Review insight work is split on GitHub — **#40** (insight-first presentation redo) and **#80** (deeper engine iteration); see `GraceNotes/docs/07-release-roadmap.md` and `03-review-insight-quality-contract.md`.
- UI tests: launch flag **`-grace-notes-reset-uitest-store`** clears the shared UI-test SwiftData store on bootstrap (default in `JournalUITests`); the journal persistence UI test omits it after `terminate()` so relaunch still reads the same file.
- Unit tests: **`ApiSecrets.cloudApiKeyOverrideForTesting`** keeps hosted `SummarizerProvider` expectations stable when `Info.plist` carries a non-placeholder developer key.
- UI tests: section **(+)** controls expose stable **`accessibilityIdentifier`** values (`JournalSectionAdd.*`) under `-ui-testing`; `addGratitude` waits for the first gratitude chip after submit.
- New tests: `CloudSummarizerPromptAndGroundingTests` (+ `CloudSummarizerTestSupport`).
- Cloud summarization: app `Info.plist` uses `$(GRACE_NOTES_CLOUD_API_KEY)`, expanded from committed `DeveloperSettings.xcconfig` and optional gitignored `DeveloperSettings.local.xcconfig` (see `DeveloperSettings.local.xcconfig.example`); `ITSAppUsesNonExemptEncryption` is `false` for export compliance.

- App **marketing version** `0.5.0`; **bundle version** (`CURRENT_PROJECT_VERSION`) `7` for Grace Notes app configurations (Debug, Release, Demo); git tag **`v0.5.0+7`**. `OrientationReleaseGate` + `lastLaunchedBundleVersion` gate upgrade orientation across **0.5.0** build bumps.
- Project-level **Debug** and **Demo** build settings use `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` so Debug-style builds still produce dSYM for symbolication.
- Shared `GraceNotes.xcscheme`: **Run** used **Release** build configuration at this ship cut (later **main** defaults **Run** to **Debug**; see Build 8 Developer).
- App target **Swift strict concurrency** set to **minimal**; removed `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` from Grace Notes app build settings.
- `StartupCoordinator.PersistenceFactory` drops the `@Sendable` requirement (aligned with relaxed concurrency checking).
- **Accessibility QA (manual):** Settings → Display & Text Size → Text Size (largest) and Accessibility → Display & Text Size → Larger Accessibility Sizes — confirm tab bar (Today / Past / Settings) and sample navigation/toolbar titles remain usable without icon overlap or severe clipping. No snapshot suite covers UIKit chrome; regressions are caught by this pass.
- Journal: milestone suggestion cards and Settings deep-links share `JournalOnboardingSuggestionEvaluator`; eligibility is recomputed at tap time before changing tabs (PR #79 review). Onboarding and iCloud continuity scans use shared UserDefaults key constants (`FirstRunOnboardingStorageKeys`, `JournalTutorialStorageKeys`, `JournalOnboardingStorageKeys`, `ReminderSettings.timeIntervalKey`, summarizer/review-insight keys) to avoid migration drift.
- UI tests: `ProcessInfo.graceNotesIsRunningUITests` centralizes UI-test detection (UITest bundle path or `-ui-testing`); SwiftData UI-test stores persist across `terminate()` + `launch()` by reusing the last XCTest session key (`active-uitest-session-key.txt`). During UI tests, gratitude chips expose stable accessibility identifiers (`JournalGratitudeChip.<index>`); the post-Seed full-screen journey is skipped; Review keeps timeline/insights chrome under the same detection so an empty journal can still reach the mode picker. `JournalUITests` forces English locale and reapplies `-ui-testing` launch arguments after every relaunch.

### 2026-03-21 — Foundation

Insight quality: Review that feels specific and grounded, better chip source material, calmer completion feedback. Release scope context: `GraceNotes/docs/07-release-roadmap.md` §0.5.0. Shipped as marketing **0.5.0** (initial line ship; bundle per Xcode at time of release).

### Added
- Journal: first-run guided tutorial on Today—dismissible hints toward Seed (at least one gratitude, need, and person) and Harvest (15 chips), plus one-time congratulations when each milestone is first reached; progress is per install with an optional UI-test reset launch argument (`#60`).
- Journal: behavior-first onboarding now starts with a minimal welcome and guides the first journal on Today one step at a time (Gratitude → Need → People → Ripening → Harvest → Abundance), replacing the earlier copy-led pager with inline section emphasis and locking (`#71`, `#73`, `#74`). *(The **Abundance** onboarding step and tier were removed in **0.5.0** build **8**; see Build 8 **Changed**.)*
- Journal / Settings: milestone-based suggestion cards can route to Settings and highlight the relevant AI, Reminders, or Data & Privacy section so optional setup stays calm and contextual (`#75`).
- Journal: one-time, skippable post-Seed full-screen journey the first time you reach Seed on Today’s guided entry (`#71`).
- Journal: brief unlock toast when completion moves up (Seed, Harvest, or full rhythm).
- (Planned, `#11`) Checkmark or equivalent when all five slots in a section are complete

### Changed
- Journal: completion semantics aligned with GitHub #67 — **Harvest** is chips-only; **Abundance** is chips plus reading notes and reflections. `completedAt` records harvest; “perfect” streak uses Abundance only (not `completedAt`). Named predicates on `JournalEntry`: `hasHarvestChips`, `hasAbundanceRhythm`. Meaning-card copy, unlock toasts, and related **zh-Hans** strings updated (short labels: **成长** / **满溢** for Ripening / Abundance). *(Superseded in **0.5.0** build **8**: Abundance tier and `hasAbundanceRhythm` removed; see Build 8 **Changed**.)*
- Settings / persistence: fresh installs now default **iCloud sync** to off, while upgrades with existing onboarding or preference signals preserve the prior implicit iCloud-on posture through a one-time preference resolution pass (`#72`).
- System sans typography uses **Outfit** app-wide: UIKit navigation bar, tab bar, and bar-button titles via appearance; SwiftUI root `font` environment; journal inputs keep explicit **Source Serif** / **Playfair** where set (including gratitude/need/person field placeholders).
- Review (#40): cloud weekly insights run only when the current week has **three or more** meaningful journal rows; sanitized AI output must reference recurring themes in narrative, resurfacing, and continuity (and avoid generic continuity phrasing) or the app falls back to on-device insights. Cloud prompt nudges one concrete link between recurring signals when the week supports it.
- (Planned, `#39`) AI prompts for chip labels tuned to improve review inputs; deterministic paths unchanged in spirit

### Fixed
- Journal: completion status info card opens and toggles reliably when tapping the pill quickly; tap outside the pill in the date row, or on the card, dismisses it. Paired pill–card geometry morph is off for this flow to avoid layout collapse; dismiss tasks are cleared when cancelled or finished (#66).

## [0.4.0] - 2026-03-20

iCloud / SwiftData trust in Settings (storage and attention copy aligned with real persistence), optional JSON **import** to restore or merge backups by calendar day, and AI connection status polish. Release scope context: `GraceNotes/docs/07-release-roadmap.md`.

### Added
- Settings → Data & Privacy → **Restore from a backup**: pick an export file, confirm replace-by-day behavior, then merge in a background `ModelContext` (security-scoped file access). Invalid files and unsupported export schema versions surface clear errors; success summarizes inserted vs replaced days.
- Settings → AI: path-aware status when AI features are on (misconfigured key, offline, soft check failure), tap the row to verify reachability to the cloud AI host, inline status under the title (plus “Tap for connection status” when nominal), and throttled auto-check on Settings open. Chip label truncation follows the same “cloud route” rule as `SummarizerProvider` (toggle + configured key).
- AI row uses a Reminders-style trailing toggle with a separate tappable title area for connection status. “Connection looks good.” clears when you leave Settings, lose network route, or start a new check (no timed dismiss).
- Unit tests for journal import (decode, schema rejection, dedupe-by-day, sanitize) plus SwiftData integration tests skipped on Simulator where a second in-memory container crashes the hosted test app.

### Changed
- Settings → **Cloud AI**: **Summarize and Insights** toggle is disabled when no usable `CloudSummarizationAPIKey` is configured; AppStorage flags are cleared when opening Settings if the key is missing.
- Settings copy: **Cloud AI** section uses a **Summarize and Insights** toggle label (section title carries “cloud”); no footer; Reminders drops the redundant intro line; **Data & Privacy** backup actions use **Export a backup** / **Restore from a backup** plus a short helper under Backup; section footers remain dropped (import confirm still explains merge-by-day).
- Data & Privacy storage summary when the journal is on CloudKit (no redundant “iCloud on” body line); attention strings use `.summary` keys; **Open Settings** in account/restriction flows uses a prominent button when signing in or fixing restrictions is the primary action.
- On-device chip labels no longer use word- or character-based “summarization”; they show a capped prefix of the user’s own text with `...` when truncated. Cloud chip summarization is unchanged.
- Review → Insights / Timeline uses the system segmented `Picker` (Liquid Glass on iOS 26+) with warm accent tint.
- App **marketing version** `0.4.0`; bundle **display name** on device home screen is `感恩记` (aligned with product naming).

### Fixed
- JSON **import** caps backup size (100 MB) and entry row count (10,000) so a malicious or corrupted export is less likely to exhaust memory or freeze the app; localized errors when limits are exceeded.
- `JournalEntry` chip arrays (`gratitudes`, `needs`, `people`) are optional in the SwiftData model so CloudKit-backed stores load: Core Data requires optional or defaulted attributes, and empty-array defaults on transformable collections are not accepted (fixes startup fallback to local-only with `NSCocoaErrorDomain` 134060).
- Hosted XCTest on Simulator: `AISettingsCloudStatusModelTests.test_misconfiguredWhenKeyMissing` is `async` so `@MainActor` UI state updates do not corrupt the heap; `PersistenceRuntimeSnapshotTests.test_makeInMemoryForTesting_matchesFactory` skips on Simulator when creating a second `ModelContainer` would crash.

### Developer
- SwiftLint `file_length` warning threshold raised to 620 for a few large SwiftUI screens.

## [0.3.5] - 2026-03-20

### Changed
- Font-copy build phase now writes to the target build directory and declares explicit output paths for deterministic app packaging.

### Developer
- Bumped app `MARKETING_VERSION` to `0.3.5` for Grace Notes app configurations.
- Updated `README.md` "What's new" content to align with this release scope.
- Aligned `GraceNotes/docs/07-release-roadmap.md` with shipped `0.3.5`, reframed `0.4.0` as iCloud/SwiftData sync reliability, and renumbered later milestones.

## [0.3.4] - 2026-03-19

### Added
- Inline completion meaning card for Today status badges (`In Progress`, `Seed`, `Harvest`), with motion-aware presentation and tap-to-dismiss behavior.
- New iCloud sync toggle in Settings data section so users can explicitly control device-local vs synced behavior.

### Changed
- Completion tier copy was renamed from `Daily Rhythm`/`Complete` to `Seed`/`Harvest` across Today, Review, and localization.
- Quick check-in completion now requires at least one entry in each chip section (gratitudes, needs, people), reducing accidental partial-completion labeling.
- Completion meaning card interaction now remains visible until intentional dismissal instead of auto-hiding.
- Review timeline now always shows an explicit status chip, including `In Progress`.
- Data privacy helper copy in Settings now explains iCloud-on/iCloud-off behavior and when preference changes apply.

### Fixed
- Updated feature, unit, and UI tests for completion thresholds, deterministic summarization expectations, reminder denied-state flow, and accessibility label targeting.

### Developer
- Synced release docs and roadmap artifacts for `0.3.4` packaging and release merge readiness.

## [0.3.3] - 2026-03-19

### Added
- Completion milestone callout in Today flow to acknowledge the first full reflection milestone.
- Accessibility/test hooks to stabilize review timeline validation in UI testing.

### Changed
- Cross-surface UI polish across Today, Review, Settings, and onboarding copy/tone for calmer, clearer guidance.
- Review timeline and insight presentation refined for better continuity and less visual duplication.
- Reminder controls and inline settings interactions tightened for clearer state feedback.
- Deterministic weekly insight generation and normalization improved for more consistent theme continuity.
- Completion badges in Today are now tappable and explain the meaning of `Daily Rhythm` and `Complete`.
- Section progress in Today now uses five-dot status indicators near each section title instead of `x of 5` copy.
- Review timeline completion chips now use consistent text-only badge styling aligned with Today labels.
- Chip/input editing states now use clearer accent and border contrast for active and pending slots.
- Settings now exposes a single `AI features` toggle that enables both cloud chip labels and AI review insights together.
- Settings AI/privacy helper copy now clearly explains cloud-on versus on-device behavior in one place.
- Reminder toggle tint and denied-state `Open Settings` button sizing were refined for better visual consistency.

### Fixed
- Journal completion logic now correctly requires full 5x5x5 completion for standard reflection gating.
- Cloud-generated chip labels now preserve the full returned phrase instead of being hard-truncated to local chip-width limits.
- On-device chip labels now use explicit ellipsis truncation while keeping deterministic fallback behavior and cloud mapping tests aligned.

### Developer
- Synced localized strings and expanded release/UAT documentation coverage for 0.3.3 packaging.

## [0.3.2] - 2026-03-18

### Added
- Dedicated reminder settings drill-in screen with explicit enable flow and denied-state recovery action.
- Reminder flow state model tests covering enable/disable, denied transitions, passive status refresh, and implicit time reschedule behavior.

### Changed
- First-launch startup now uses an immediate loading surface with rotating reassurance copy and retry-safe recovery.
- Settings reminder row now navigates to reminder details instead of triggering permission behavior from an inline toggle.
- Reminder activation now derives from live authorization plus pending notification request state.
- Reminder scheduler now separates passive status reads from explicit permission request paths.

### Fixed
- Fixed first-launch freeze perception by avoiding blank/frozen startup behavior while persistence initializes.
- Fixed reminder trust gaps where UI could imply reminders were enabled without confirmed scheduling outcome.
- Fixed input-pipeline regressions that could drop active text or dismiss keyboard momentum on entry/chip commit paths.

### Developer
- Updated release documentation and initiative testing evidence for `#31`, `#33`, `#36`, and `#37`.

## [0.3.1] - 2026-03-18

### Added
- (none)

### Changed
- Updated release and automation docs to align with current Grace Notes naming, release cadence, and test workflow.
- Refined test and project configuration references to use current targets/schemes and simulator defaults.
- `Makefile` test targets now pass `-parallel-testing-enabled NO` to reduce simulator launch contention during full-suite execution.
- `make test-all` now hard-resets simulators before each scheme run to reduce Xcode simulator preflight contention between `GraceNotes` and `GraceNotes (Demo)` UI-test passes.
- Chips now use context-menu actions for rename/delete, support drag-to-reorder, and no longer expose a delete-confirmation toggle in Settings.
- Settings privacy/help copy strings were flattened into valid single-line localized literals to restore successful Swift compilation.
- `ChipReorderDropDelegate` now exposes direct helper entry points (`dropEntered()`, `dropUpdated()`, `performDrop()`) while preserving `DropDelegate` conformance, which keeps reorder behavior testable across SDK API changes.
- Cloud review insight tests now use a non-cached `URLSession` test configuration and resilient request-body capture (`httpBody` or `httpBodyStream`) for prompt assertion coverage.

### Fixed
- Removed remaining legacy entitlement and test-path references so project assets consistently use `GraceNotes*` naming.
- Stabilized UI test execution by removing the template launch performance case and reducing launch-test configuration fan-out that caused intermittent simulator preflight launch denials.
- Chip label fallback now uses deterministic snippets (first 5 words, or first 5 Chinese characters) with reliable end-fade truncation behavior when AI summarization is unavailable (#39).
- Repaired test/build breakages caused by stale symbol usage and missing return paths in chip-editing view-model logic.
- Updated chip reorder tests for newer SwiftUI drag/drop APIs where `DropInfo` is no longer mockable as a protocol type.
- Corrected deterministic summarizer test expectations to match the current 20-character chip-label budget behavior.

### Developer
- Reorganized GraceNotes docs into numbered structure (01–07), archived legacy plans to docs/archive.
- Added release roadmap (07-release-roadmap.md) mapping strategy to version sequence.
- Consolidated review insight examples into 04-review-insight-examples.md; removed obsolete doc/review-insight-examples-and-spec.md.
- Added agent-log initiative structure and validate-agent-log script for issue #41.
- Added role governance section to AGENTS.md; Makefile verify-agent-log targets.
- Consolidated test-suite updates across Journal and repository coverage after the naming migration cleanup.
- Continued maintenance pass on project metadata (`project.pbxproj`), `README.md`, and `Makefile` for release readiness.
- Added simulator reset helper target (`make reset-simulators`) and wired it into full-suite automation.
- Tightened cloud insight prompt-quality test synchronization by waiting for captured request traffic before asserting request payload content.

## [0.3.0] - 2026-03-17

0.3.0 is a major rebranding release that moves the app and project identity from legacy Five Cubed Moments naming to **Grace Notes**.

### Added
- No net-new product features in this release; the focus is full naming and identity alignment across app experience and project configuration.

### Changed
- Onboarding now consistently uses Grace Notes product language, including the welcome headline (`Welcome to Grace Notes`).
- Progress framing now uses less pressure-driven wording (`fuller reflection sessions`) instead of legacy `5³`-centric phrasing.

### Fixed
- Chinese localization now fully covers the renamed Review, Settings, and Onboarding surfaces, including deterministic review insight copy.

### Developer
- Rebranded project/app/test paths from `FiveCubedMoments*` to `GraceNotes*` and aligned Xcode schemes/module naming
- Updated iCloud entitlement container identifiers to the Grace Notes bundle naming
- Removed `GRACE_NOTES_CLOUD_API_KEY` fallback; cloud key now resolves from Info.plist or placeholder only

## [0.2.3] - 2026-03-17

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
- iCloud/CloudKit capability wiring (`GraceNotes.entitlements`) and cloud-capable SwiftData configuration path
- First-run onboarding screen introducing structure, review value, and low-pressure progress
- Sprint-ready planning doc for review + onboarding execution (`review-onboarding-sprint-plan-2026-03-17.md`)

### Changed
- JournalEntry model: `bibleNotes` → `readingNotes` with `@Attribute(originalName:)` for schema migration; CloudKit-compatible declaration-time defaults
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
- Demo build configuration and scheme (`GraceNotes (Demo)`) with `USE_DEMO_DATABASE` for running with pre-seeded sample data; `DemoDataSeeder` and `PerformanceTrace` utilities
- Added `StreakCalculator` service and `StreakSummary` value type for derived, read-time streak metrics
- Added reminder and streak test coverage for permission flows, time scheduling, skipped-day breaks, and day-boundary normalization
- Removed unused localization key `"%d of %d — editing"`
- Added tests for deterministic review insights, cloud review insights decoding, provider fallback behavior, and JSON export payload integrity
- Added completion-level test coverage for Journal model and ViewModel states
- Improved test naming consistency for deterministic review insights suite
- Strengthened cloud review tests with meaningful thrown-error assertions and payload clamping checks

## [0.2.2] - 2026-03-17

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
- Chip deletion UX: long-press to delete with optional confirmation (Settings: "Confirm chip deletion"); removed deletion mode, wiggle, minus badge, double-tap (later superseded in 0.3.1 by context-menu delete without the setting)
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
