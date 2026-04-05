# Localization (Grace Notes)

This project uses **String Catalog** (`GraceNotes/GraceNotes/Localizable.xcstrings`) with **English** and **Simplified Chinese** (`zh-Hans`). Keys are **stable identifiers**; user-visible text lives in the catalog.

## Naming rules

- Use **dot-separated** semantic keys: `feature.screen.role` or `domain.subdomain.purpose`.
- Top-level domains in this repo include:
  - `app`, `shell`, `common`, `calendar`, `startup`, `onboarding`, `journal`, `past`, `review`, `sharing`, `notifications`, `tutorial`, `settings`, `data`, `accessibility`
- Prefer **feature-specific** keys over generic English sentences as keys.
- Use **lowerCamelCase** segments (e.g. `sectionTitle`, `mergeConflict.title`), not Title Case in key names.
- Shared strings (OK, Cancel, Today) live under **`common.*`** or **`shell.*`** when they are tab chrome.

## Adding a new string

1. Pick a semantic key (see Naming rules).
2. Add the key in **Xcode** → Localizable String Catalog, or edit `Localizable.xcstrings` JSON (keep valid JSON; preserve `en` and `zh-Hans` or add locales consistently).
3. Reference it in Swift:

```swift
Text(String(localized: "journal.section.gratitudesTitle"))
```

4. For **format strings**, use positional specifiers (`%1$@`, `%2$d`) and document placeholders in the catalog **comment** (see below).

## Placeholders and format strings

- Prefer **one format string** with positional placeholders instead of concatenating translated fragments.
- For **count-sensitive** English copy, prefer:
  - **String Catalog plural variants** (variations / plural rules) when the sentence structure allows, or
  - A **single template** with explicit placeholders when logic post-processes (see weekly insight templates under `review.insights.*`).

Some templates use a literal `day(s)` substring in English that **runtime code replaces** with localized “day” / “days” (`WeeklyInsightCandidateBuilder+Candidates.renderLocalizedDayCountTemplate`). Translators should preserve that substring when English needs it, or adapt the sentence in `zh-Hans` without relying on that hack.

## Developer comments (catalog)

Use the string entry’s **comment** field for:

- Placeholder meanings (`%1$@` = section name)
- Non-obvious context (e.g. VoiceOver-only label)
- Strings that are **not** full sentences in the UI (e.g. single-word growth stage labels)

## Stale / unused keys

- Run `python3 Scripts/localization_audit.py` from the repo root. It reports:
  - keys in the catalog not referenced from Swift (with a small allowlist for dynamic template keys)
  - duplicate English values across keys (possible drift)
- **Deleting** unused keys is safe only when you are sure nothing loads them dynamically. Keys passed to `String(localized: String.LocalizationValue(key))` are **not** visible to a simple text search—keep the allowlist in `Scripts/localization_audit.py` in sync if you add more dynamic keys.

## Anti-patterns

- **English sentence as the key** (hard to grep, unstable when copy edits).
- **Concatenating** localized strings for grammar (breaks in other languages).
- **`NSLocalizedString` with raw English keys**—use `String(localized:)` or `String(localized: String.LocalizationValue(_:))` so the catalog stays the source of truth.
- **Duplicating the same English under different keys** without a product reason—review duplicate groups from the audit script.

## Related scripts

- `Scripts/localization_migrate.py` — one-time bulk rename helper (already applied; kept for history).
- `Scripts/localization_audit.py` — ongoing catalog vs. code audit.
