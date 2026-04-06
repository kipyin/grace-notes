# Sharing design (GitHub #168) — locked decisions

Mirror of the unified plan for composer-first sharing. Implementation source of truth is the shipped code; this document records product and UX decisions.

## Approach

- **Composer-first only:** Share opens `JournalShareComposerView`; `UIActivityViewController` runs only after **Share** in the composer.
- **No second sheet:** Refine / “Edit what’s included” removed. Redaction, section include/exclude, style, watermark, and badge are edited on the first sheet.
- **Privacy:** Redacted lines export as **visible bars** only — the bitmap must not contain underlying secret glyphs (no blur of real text).

## Styles

Exactly three presets — `paperWarm`, `editorialMist`, `sunriseGradient` — closed enum, not an open editor. Export uses light appearance (`preferredColorScheme(.light)`).

## Draft flags

- `showWatermark` — default **on**
- `showCompletionBadge` — default **off**
- `completionLevel` — from `JournalExportPayload` / `exportSnapshot()`

## Composer IA

- Top: Cancel + **Share** (primary).
- Scrollable **live card preview**: interactive lines (redaction), **section headers** (title + eye / eye.slash), **stub rows** for excluded sections (preview only).
- Style chips + watermark toggle + completion badge toggle + short hints for tap-to-redact and sections.

## Sections

- **Excluded sections:** omitted from exported bitmap. In composer preview only, a **compact stub row** per excluded section so the user can restore. Stubs never appear in the final image (`includePreviewStubs` vs export build).

## Layout

- **Preview vs export width:** `usesFixedExportWidth` — flexible in composer; fixed width in `JournalShareRenderer` for stable bitmap dimensions.

## Redaction bar (v1)

- ~18pt height, `AppTheme.textMuted` @ ~0.35 fill, solid — no label required.
