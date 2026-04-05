# Localization refactor summary (2026)

## Scope

- **Catalog**: `GraceNotes/GraceNotes/Localizable.xcstrings`
- **Before**: 569 keys (many legacy English-sentence keys, stale entries, and unused strings)
- **After**: 339 keys — **only strings referenced** from Swift (plus merged dynamic insight templates)
- **Removed**: ~230 keys that had **no** `String(localized:)` / `localized:` reference (most were already marked `extractionState: stale` in Xcode)

## Convention

Semantic, dot-separated keys grouped by domain, for example:

- `onboarding.welcome.title`, `journal.section.gratitudesTitle`, `settings.dataPrivacy.import.mergeConflict.title`, `review.insights.starterReflection`, `shell.tab.today`

Prefix mappings applied in bulk:

| Old prefix | New prefix |
|------------|------------|
| `DataPrivacy.` | `settings.dataPrivacy.` |
| `AppTour.` | `tutorial.appTour.` |
| `PastDrilldown.` | `past.drilldown.` |
| `PastSearch.` | `past.search.` |
| `PastStatisticsInterval.` | `settings.pastStatisticsInterval.` |
| `ThemeDrilldown.` | `review.themeDrilldown.` |
| `Settings.` | `settings.` |
| `Review.` | `review.` |

Hundreds of **plain-English** keys were mapped to semantic names (see `Scripts/localization_migrate.py`, `PLAIN_TO_SEMANTIC` / `_add_block`).

## Deleted keys

Removed keys that were **not** referenced in code (see pre-refactor catalog minus post-refactor). They were predominantly:

- Legacy weekly insight / pairing strings superseded by current generators
- Old UI copy no longer present in Swift
- Duplicate or experiment strings left in the catalog

**Deleted aggressively** only where grep showed **zero** references. If you need a specific old key, recover it from git history before this merge.

## Renamed keys

Full rename table: **`Scripts/localization_migrate.py`** (`build_full_map()` → `plain` map + prefix rules). Representative examples:

| Old | New |
|-----|-----|
| `Welcome to Grace Notes` | `onboarding.welcome.title` |
| `DataPrivacy.import.mergeConflict.title` | `settings.dataPrivacy.import.mergeConflict.title` |
| `AppTour.pageIndicator` | `tutorial.appTour.pageIndicator` |
| `PastStatisticsInterval.phrase.lastOneWeek` | `settings.pastStatisticsInterval.phrase.lastOneWeek` |

## Dynamic / runtime-loaded keys (not plain string literals)

Weekly insight templates use `String(localized: String.LocalizationValue(key))` with these keys (must stay in catalog):

- `review.insights.recurringPeople.observation` / `.action`
- `review.insights.recurringTheme.need.observation` / `.action`
- `review.insights.recurringTheme.gratitude.observation` / `.action`
- `review.insights.needsGratitudeGap.observation` / `.action`
- `review.insights.continuityShift.observation` / `.action`
- `review.insights.reflectionDays.observation`

## Duplicate or near-duplicate English (manual review)

Run `python3 Scripts/localization_audit.py`. Known duplicate **English** values shared across keys (often intentional: same word in different UI roles):

- **Show more** — `common.showMore`, `review.actions.browseRecurringThemes`, `review.actions.browseTrendingThemes`
- **Sprout** — `journal.growthStage.started`, `tutorial.appTour.congrats.headline`
- **Off** — `common.off`, `settings.dataPrivacy.scheduledBackup.interval.off`
- **Import**, **Backup & import**, **Save a backup copy**, **Auto backup**, **Advanced settings** — pairs under settings / data privacy

Product decision: keep separate keys when **context** differs (VoiceOver, navigation title vs. body), even if English matches.

## Possible stale keys (low confidence)

None flagged in the final catalog after the audit. If Xcode’s **Import / Export** or **Compile** adds `extractionState: stale` again, reconcile with `Scripts/localization_audit.py`.

## Risky areas

- **Weekly insights**: template strings depend on placeholder replacement order; Chinese translations were preserved from the pre-refactor catalog.
- **Growth stage labels** (`journal.growthStage.*`) appear in multiple surfaces (badges, tour, onboarding); renaming touched many files—watch for QA on those flows.
