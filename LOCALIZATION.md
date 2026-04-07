# Localization (Grace Notes)

This project uses **String Catalog** (`GraceNotes/GraceNotes/Localizable.xcstrings`) with **English** and **Simplified Chinese** (`zh-Hans`). Keys are **stable identifiers**; user-visible text lives in the catalog.

## Naming rules

- Use **dot-separated** semantic keys: `feature.screen.role` or `domain.subdomain.purpose`.
- Top-level domains in this repo include:
  - `app`, `shell`, `common`, `calendar`, `startup`, `onboarding`, `journal`, `past`, `review`, `sharing`, `notifications`, `tutorial`, `settings`, `data`, `accessibility`
- Prefer **feature-specific** keys over generic English sentences as keys.
- Use **lowerCamelCase** segments (e.g. `sectionTitle`, `mergeConflict.title`), not Title Case in key names.
- Shared strings (OK, Cancel, Today) live under `**common.*`** or `**shell.***` when they are tab chrome.

## Adding a new string

1. Pick a semantic key (see Naming rules).
2. Add the key in **Xcode** → Localizable String Catalog, or edit `Localizable.xcstrings` JSON (keep valid JSON; preserve `en` and `zh-Hans` or add locales consistently).
3. Reference it in Swift:

```swift
Text(String(localized: "journal.section.gratitudesTitle"))
```

1. For **format strings**, use positional specifiers (`%1$@`, `%2$d`) and document placeholders in the catalog **comment** (see below).

## Placeholders and format strings

- Prefer **one format string** with positional placeholders instead of concatenating translated fragments.
- For **count-sensitive** English copy, prefer:
  - **String Catalog plural variants** (variations / plural rules) when the sentence structure allows, or
  - A **single template** with explicit placeholders when logic post-processes (see weekly insight templates under `review.insights.`*).

Some templates use a literal `day(s)` substring in English that **runtime code replaces** with localized “day” / “days” (`WeeklyInsightCandidateBuilder+Candidates.renderLocalizedDayCountTemplate`). Translators should preserve that substring when English needs it, or adapt the sentence in `zh-Hans` without relying on that hack.

## Developer comments (catalog)

Use the string entry’s **comment** field for:

- Placeholder meanings (`%1$@` = section name)
- Non-obvious context (e.g. VoiceOver-only label)
- Strings that are **not** full sentences in the UI (e.g. single-word growth stage labels)

## Stale / unused keys

- Run `grace l10n audit` from the repo root (after installing `gracenotes-dev`; see `AGENTS.md`). By default it prints a **short status**, capped samples, and **next steps**; use **`grace l10n audit --full`** for exhaustive tables (all unused keys, duplicate groups, and multi-file references).
- The audit covers:
  - keys in the catalog not referenced from Swift (with a small allowlist for dynamic template keys)
  - duplicate English values across keys (possible drift)
- **Deleting** unused keys is safe only when you are sure nothing loads them dynamically. Keys passed to `String(localized: String.LocalizationValue(key))` are **not** visible to a simple text search—keep the allowlist in `Scripts/gracenotes-dev/src/gracenotes_dev/cli/l10n_cmd.py` (`DYNAMIC_TEMPLATE_KEYS`) in sync if you add more dynamic keys.

## Anti-patterns

- **English sentence as the key** (hard to grep, unstable when copy edits).
- **Concatenating** localized strings for grammar (breaks in other languages).
- **`NSLocalizedString` with raw English keys** — use `String(localized:)` or `String(localized: String.LocalizationValue(_:))` so the catalog stays the source of truth.
- **Duplicating the same English under different keys** without a product reason—review duplicate groups from the audit script.

## Related tooling

- **`grace l10n audit`** — compares `Localizable.xcstrings` to Swift `String(localized:)` / `localized:` references (see `Scripts/gracenotes-dev/…/cli/l10n_cmd.py`). A prior one-off bulk rename lived in `Scripts/localization_migrate.py` (removed); recover from git history if needed.
- **`grace l10n review`** — interactive, TTY-only walkthrough of keys used in Swift, grouped by product surface (first run, Today, Past, Settings, shared chrome), showing English and zh-Hans plus optional audit hints from the same scan as `audit`. Optional per-key surface fixes live in repo-root `l10n-review-overrides.toml`. The command does not edit the string catalog; it can append Markdown notes to a file you specify (default timestamped file under the repo root, gitignored).

