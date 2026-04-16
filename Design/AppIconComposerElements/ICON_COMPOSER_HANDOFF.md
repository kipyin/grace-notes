# Grace Notes Liquid-Glass Icon Handoff

## Deliverables

- `01_loop.svg`
- `02_neutralDots.svg`
- `03_accentDot.svg`

All three files are full-canvas (`1024x1024`) with transparent backgrounds and aligned coordinates for direct import into Icon Composer.

**Loop geometry (intent):** The stroke is a single continuous curve: it rises from the lower left, threads the row (passing through the third dot’s centerline), forms a balanced teardrop above the dots, and **terminates on the accent (fifth) dot near its 3 o’clock**. **Canonical geometry is whatever ships** in this folder’s `01_loop.svg` and in `GraceNotesIconLiquidGlass.icon` after Icon Composer (layers can translate paths); use those files—not fixed pixel coordinates in this doc—when checking or editing alignment.

## Figma Source

- File: [GraceNotes Liquid Glass Icon Draft](https://www.figma.com/design/GLVjzNVCfux0IrSdQ1eRxc)
- Master frame: `Icon_Master_1024`
- Preview board: `Variant_Previews` (`Default_Mock`, `Dark_Mock`, `Tinted_Mock`)

## Import Into Icon Composer

1. In Xcode, open the app icon asset and choose **Edit in Icon Composer**.
2. Drag all three SVGs into Icon Composer at once.
3. Confirm order and naming:
   - `01_loop` (top linework)
   - `02_neutralDots` (four neutral dots)
   - `03_accentDot` (warm accent dot)
4. Keep each imported layer full-size and aligned at `1024x1024`.
5. Do not add a squircle mask manually; system masking is automatic.

## Liquid-Glass Finishing Recipe

Use these as starting points and tune visually:

- **Default appearance**
  - Keep contrast soft but clear.
  - Use moderate translucency and blur on `01_loop` and `02_neutralDots`.
  - Keep `03_accentDot` less translucent than neutrals so the accent remains the memory anchor.

- **Dark appearance**
  - Lift brightness of line/dot material so shapes stay legible on dark context.
  - Slightly reduce blur relative to default to avoid muddy edges.
  - Keep accent warm, but raise luminance a bit to avoid dull orange.

- **Tinted appearance**
  - Treat all three layers as one tonal family.
  - Reduce reliance on hue differences; preserve recognizability by silhouette and spacing.
  - Keep loop stroke crisp so the symbol still reads when tint compresses colors.

## Export Back To Xcode

1. In Icon Composer, finalize default/dark/tinted variants.
2. Save back into the app icon asset in Xcode.
3. Verify these files in `GraceNotes/GraceNotes/Assets.xcassets/AppIcon.appiconset`:
   - base icon image
   - dark appearance image
   - tinted appearance image
4. Build and visually confirm on Home Screen in light and dark mode.
