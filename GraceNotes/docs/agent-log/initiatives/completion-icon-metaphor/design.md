# Completion icon metaphor — Designer spec

## Decision

- **Ladder:** Keep a **single agrarian story** from Soil through Harvest, then use a **deliberate shift** at Abundance to **full light** (sun): a poetic “day fully open” peak that does not compete with Harvest’s spark milestone; **criteria** for Abundance (chips + notes + reflections) stay defined in copy, not in the glyph alone.
- **SF Symbol mapping** (replace values in `JournalCompletionLevel.completionStatusSystemImage(isEmphasized:)`):

| Tier | `isEmphasized == false` | `isEmphasized == true` | One-sentence intent |
|------|-------------------------|-------------------------|----------------------|
| **Soil** | `circle.dotted` | `circle.dotted` | Dotted circle reads as sparse, uncultivated ground before anything is planted. |
| **Seed** | `leaf` | `leaf.fill` | A leaf reads as early growth after Soil; outline when calm, filled when highlighted or celebrating. |
| **Ripening** | `tree` | `tree.fill` | A tree reads as established growth that is maturing toward something worth gathering, not another leaf badge. |
| **Harvest** | `sparkles` | `sparkles` | Sparkles signal a celebratory chip milestone; pill scale and shadow still carry celebration so the glyph stays consistent. |
| **Abundance** | `sun.max` | `sun.max.fill` | The sun reads as fullness and warmth—a calm “complete day” peak—while product meaning for notes and reflections stays in strings, not in the icon silhouette. |

- **Plan open questions (resolved for build):**
  1. **Abundance:** **Poetic peak** (sun), not criteria-literal books or a bare checkmark; copy and the info card carry notes/reflections.
  2. **Harvest:** Primary signal is **celebratory fullness** (spark iconography); copy still defines Harvest as fifteen chips filled, while **Abundance** stays visually distinct (sun vs. sparkles).

## Open Questions

- None blocking implementation; **Builder** should sanity-check **small-size legibility** (pill + path row) and **bold/regular** rendering at largest Dynamic Type sizes. If `sun.max` feels crowded next to `sparkles`, acceptable fallback for Abundance: `sun.horizon` / `sun.horizon.fill` — flag back to **Designer** only if swapped.

## Next Owner

- **Builder:** Implement the table above in `JournalCompletionLevel+CompletionStatusImage.swift`, then run **SwiftLint** and **GraceNotesTests** on macOS.
- **Test Lead:** Update tests only if any test asserts exact symbol names (unlikely); otherwise smoke the pill, `PostSeedJourneyPathStrip`, and unlock toast surfaces in Simulator.

## Inputs Reviewed

- Strategist brief / plan: completion icon metaphor (label–icon tension, single source of truth, unchanged thresholds).
- `.impeccable.md` — calm, low gamification, clarity over novelty; avoid trophy-like “you won” cues where a softer metaphor works.
- `JournalCompletionLevel+CompletionStatusImage.swift`, `JournalCompletionPill.swift`, `PostSeedJourneyView.swift` (`PostSeedJourneyPathStrip`).
- Issue #67 completion alignment — Harvest = fifteen chips; Abundance = rhythm including notes/reflections.
- `Localizable.xcstrings` accessibility strings such as “Shows what Harvest means for today.” — **tier-named**, not glyph-specific; **no copy change required** for this symbol pass unless spoken descriptions are later tied to a particular shape.

## Rationale

- **Adjacent tiers** stay distinguishable: dotted circle → leaf → tree → sparkles → sun (Ripening’s tree stays distinct from Seed’s leaf).
- **Harvest vs. Abundance:** Harvest reads as **moment of reward** (sparkles); Abundance reads as **fullness / light** (sun). Tier meanings in copy remain the source of truth for rules.
- **Emphasis pattern** matches existing contract: outline when calm, fill when highlighted or celebrating (Soil unchanged on both paths).

## Risks

- **`leaf` / `tree`:** Slightly more detail at tiny sizes; mitigated by iOS 17+ SF Symbol weights and Builder verification.
- **Spark iconography:** Harvest uses **`sparkles` only** (calm and celebrating share the same glyph; pill animation carries emphasis). If it feels too subtle at minimum size, acceptable fallback: `sparkles.rectangle.stack` / `sparkles.rectangle.stack.fill` (still spark-forward).
- **Sun for Abundance:** Does not encode “notes + reflections” by itself; users rely on **tier name + info copy**. Slightly overlaps metaphorically with “warmth” elsewhere in the app—acceptable if silhouette stays distinct from Harvest sparkles.
