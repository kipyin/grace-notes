---
initiative_id: release-0-3-3-ui-polish
role: Architect
status: in_progress
updated_at: 2026-03-18
related_release: 0.3.3
---

# Architecture

## Inputs Reviewed

- [GraceNotes/docs/agent-log/initiatives/release-0-3-3-ui-polish/brief.md](./brief.md)
- [GraceNotes/docs/07-release-roadmap.md](../../07-release-roadmap.md)
- [.impeccable.md](../../../../.impeccable.md)
- [.agents/skills/audit/SKILL.md](../../../../.agents/skills/audit/SKILL.md)
- [.agents/skills/polish/SKILL.md](../../../../.agents/skills/polish/SKILL.md)
- [.agents/skills/frontend-design/SKILL.md](../../../../.agents/skills/frontend-design/SKILL.md) and reference docs
- [GraceNotes/GraceNotes/DesignSystem/Theme.swift](../../../GraceNotes/DesignSystem/Theme.swift)
- [GraceNotes/GraceNotes/Application/GraceNotesApp.swift](../../../GraceNotes/Application/GraceNotesApp.swift)
- [GraceNotes/GraceNotes/Application/StartupLoadingView.swift](../../../GraceNotes/Application/StartupLoadingView.swift)
- [GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift](../../../GraceNotes/Features/Onboarding/OnboardingScreen.swift)
- [GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift](../../../GraceNotes/Features/Journal/Views/JournalScreen.swift)
- [GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift](../../../GraceNotes/Features/Journal/Views/ReviewScreen.swift)
- [GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift](../../../GraceNotes/Features/Settings/SettingsScreen.swift)
- [GraceNotes/GraceNotes/Features/Settings/ReminderSettingsDetailScreen.swift](../../../GraceNotes/Features/Settings/ReminderSettingsDetailScreen.swift)

## Decision

Ship `0.3.3` as a bounded, cross-surface UI polish release focused on cohesion, state clarity, and calm finish for existing flows. This release follows the reliability fixes shipped in `0.3.2` and is intended to make those repaired flows feel intentionally finished rather than merely stabilized. It explicitly rejects redesign work, new feature scope, and any roadmap competition with the planned `0.4.0` insight-quality release. The work stays patch-sized: refinements to presentation and consistency across the four primary surfaces, without changing product shape.

## Goals

- Achieve visual and tonal consistency across onboarding or first-launch presentation, Today, Review, and Settings.
- Improve spacing, typography hierarchy, copy consistency, labels, and interaction feedback on existing screens.
- Make loading, empty, success, and error states feel clear and intentionally finished rather than abrupt or visually rough.
- Strengthen calmness and trust cues so existing flows feel more intentional after the `0.3.2` stability work.
- Keep the release describable as polish and cohesion, not as a disguised feature release.

## Non-Goals

- No new product features, feature flags, or behavior changes that materially expand app capability.
- No information architecture redesign, navigation restructuring, or broad visual rebrand work.
- No `0.4.0` insight-quality work: stronger review summaries, AI prompt changes, or new review mechanics.
- No trust-layer expansion: import, sync, backup, or privacy-control additions.
- No performance investigations except where a tiny presentation fix is required to make an already-shipped flow feel responsive.
- No dark-mode support expansion; the app remains light-mode-first. Any dark-mode token work is deferred to a later release.

## Technical Scope

### Polish Dimensions (SwiftUI-Relevant)

| Dimension | "Done" in SwiftUI Terms |
|----------|-------------------------|
| **Visual alignment & spacing** | Shared spacing/radius tokens where practical; consistent list/card insets; optical alignment of icons and text; no stray literals where theme values are expected (e.g. repeated `padding(8)`, `cornerRadius: 14` vs shared constants). |
| **Typography hierarchy** | Consistent use of `AppTheme.warmPaperHeader` and `warmPaperBody`; stable hierarchy between navigation titles, section headers, body, metadata, and status labels; Dynamic Type–safe sizing where applicable. |
| **Color & contrast** | Semantic use of `AppTheme` tokens; no hard-coded `.foregroundStyle(.white)` or `.foregroundStyle(.red)` for app-branded surfaces; error/success surfaces use theme-derived colors where they exist. Contrast meets WCAG AA for text. |
| **Interaction states** | Default, pressed, disabled, loading for tappable controls; mapped to SwiftUI `ButtonStyle`, `disabled`, `ProgressView`, and existing patterns. Error and success states use explicit messaging (alerts, inline text, toast). |
| **Loading/empty/error/success** | Each primary surface has explicit, calm messaging and visually consistent state containers where relevant. No generic "Loading..." where context-specific copy fits; empty states acknowledge and guide. |
| **Copy and labels** | Terminology and capitalization normalized across tabs, sections, buttons, alerts, helper text, and empty states. Tone: calm, warm, supportive per `.impeccable.md`. |

### Surface Inventory and Bounded Polish Items

#### 1. Onboarding and first launch

| File | Bounded polish items |
|------|----------------------|
| `StartupLoadingView.swift` | Replace `.foregroundStyle(.white)` on retry button with theme-derived foreground for accent background; ensure loading/retry/disabled states are visually distinct; spacing and corner radius aligned with shared tokens. |
| `OnboardingScreen.swift` | Replace `.foregroundStyle(.white)` on primary CTA with theme-derived foreground; align card padding and corner radius with other surfaces; ensure Continue/Get Started hierarchy and tap feedback are consistent. |

#### 2. Today / journal

| File | Bounded polish items |
|------|----------------------|
| `JournalScreen.swift` | Replace `.foregroundStyle(.red)` for save error with `AppTheme` semantic error color (add if missing); ensure share alert copy is specific and calm; align spacing between sections. |
| `SequentialSectionView.swift`, `EditableTextSection.swift`, `ChipView.swift`, `DateSectionView.swift` | Spacing and hierarchy consistency; input/card styling aligned with `WarmPaperInputStyle` and paper tokens; chip and section layout use shared spacing. |

#### 3. Review (Insights + Timeline)

| File | Bounded polish items |
|------|----------------------|
| `ReviewScreen.swift` | Loading spinner in insights card; empty state copy and layout; segmented picker and list row alignment; `ReviewSummaryCard` and `HistoryRow` spacing/hierarchy; completion badge chip styling aligned with theme. |

#### 4. Settings

| File | Bounded polish items |
|------|----------------------|
| `SettingsScreen.swift` | Export overlay and button disabled/loading treatment; alert copy consistency (avoid generic "OK" where "Dismiss" or action-specific label fits); footer and section header hierarchy. |
| `ReminderSettingsDetailScreen.swift` | Button hierarchy (bordered vs borderedProminent) and disabled/loading states; status text and guidance copy tone; spacing between controls and sections. |

### Shared Theme Additions (Limited to 0.3.3 Needs)

- Add semantic `error` (or equivalent) color to `AppTheme` if save/share/alert error surfaces need a theme-derived alternative to `.red`.
- Add shared spacing/radius constants only where they reduce duplication and inconsistency; avoid over-engineering.
- Do not introduce a full design-token system; extend the existing `AppTheme` surface minimally.

### Impeccable-Style Skill Utilization

Impeccable-style skills are the systematic review and execution framework for this polish release. They are used to bound, prioritize, and verify the work—**not** to expand scope. Use them as follows:

| Skill | When to use | Scope guard |
|-------|-------------|-------------|
| `/audit` | Before implementation to establish a prioritized quality inventory across the four in-scope surfaces. Also optionally at the end for cross-surface verification. | Audit findings must map to in-scope polish dimensions; defer out-of-scope items. |
| `/polish` | **Required** after each surface-level implementation pass, and again in the final cross-surface pass. Verifies spacing, typography, interaction states, copy, and state handling. | Use the polish checklist; do not add new features or redesign. |
| `frontend-design` | As the style-quality foundation and anti-pattern check for all polish work. | Adapt to SwiftUI/iOS; do not copy web/CSS patterns literally. |
| `teach-impeccable` | **Conditional**: Run only if `.impeccable.md` no longer provides adequate design context. For 0.3.3, `.impeccable.md` is the approved source. | Skip if design context is sufficient. |

**Supporting skills** (use only when findings cluster around one dimension and map cleanly to in-scope polish):

| Dimension cluster | Suggested skill | Use when |
|-------------------|-----------------|----------|
| Spacing, rhythm, alignment, insets | `/arrange` | Layout feels monotonous or inconsistent; spacing/radius values diverge across a surface. |
| Typography hierarchy, size, weight | `/typeset` | Font usage or hierarchy is inconsistent; readability or scaling issues. |
| Labels, alerts, empty/error copy | `/clarify` | Copy is vague, generic, or tone-inconsistent; labels need normalization. |
| Theme/token consistency | `/normalize` | Hard-coded colors or values; visual patterns deviate from `AppTheme`. |
| Loading, empty, error, success states | `/harden` | State messaging or edge-case handling is weak or missing. |

## Affected Areas

- `GraceNotes/GraceNotes/DesignSystem/Theme.swift` — optional semantic error color and spacing/radius constants.
- `GraceNotes/GraceNotes/Application/StartupLoadingView.swift` — CTA foreground, state styling.
- `GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift` — CTA foreground, card spacing.
- `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` — save error styling, alert copy.
- `GraceNotes/GraceNotes/Features/Journal/Views/SequentialSectionView.swift`, `EditableTextSection.swift`, `ChipView.swift`, `DateSectionView.swift` — spacing and hierarchy.
- `GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift` — loading, empty, card, and row polish.
- `GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift` — export overlay, alert copy.
- `GraceNotes/GraceNotes/Features/Settings/ReminderSettingsDetailScreen.swift` — button and status polish.

## Risks and Edge Cases

- Polish can sprawl: stick to the surface inventory and dimension checklist; avoid "while we're here" refactors.
- Cross-app cleanup can surface inconsistencies that tempt broader redesign: explicitly defer; document as follow-up.
- Many small touches increase regression risk: run the polish skill per surface and validate close criteria before merging.
- Hard-coded color replacement (`.red`, `.white`) must not reduce contrast or violate accessibility expectations.
- Dynamic Type and VoiceOver: verify that hierarchy and touch targets remain usable at larger text sizes and with accessibility features on.
- `prefers-reduced-motion`: respect where transitions exist; do not introduce new motion that ignores this preference.

## Sequencing

1. **Audit** — Run `/audit` on the full 0.3.3 scope (onboarding, first launch, Today, Review, Settings). Establish a prioritized defect inventory and identify systemic issues. Use the audit report to drive shared-foundation and surface work; **do not** treat audit findings as scope expansion—only address items that map to in-scope polish dimensions.
2. **Shared polish foundation** — Add only the minimal theme extensions needed (e.g. semantic error color, 1–2 spacing constants) where the audit shows recurring token/spacing/state problems. Limit scope to what 0.3.3 clearly requires.
3. **First-launch and onboarding** — Implement polish for `StartupLoadingView` and `OnboardingScreen`. If issues cluster (e.g. layout, copy, state handling), run the narrowest relevant skill (`/arrange`, `/clarify`, `/harden`) first. **Then** run `/polish` on this surface before proceeding. Validate first impression on device.
4. **Today / journal** — Implement polish for `JournalScreen` and shared journal components. Run supporting skills if findings cluster. **Then** run `/polish` on this surface. Validate save/share/error flows and section consistency.
5. **Review** — Implement polish for `ReviewScreen`, insights card, empty state, timeline rows. Run supporting skills if needed. **Then** run `/polish` on this surface. Validate Insights and Timeline modes.
6. **Settings** — Implement polish for `SettingsScreen` and `ReminderSettingsDetailScreen`. Run supporting skills if needed. **Then** run `/polish` on this surface. Validate export and reminder flows.
7. **Cross-surface verification** — Run `/polish` once across all surfaces. Do one global consistency sweep for terminology, capitalization, and visual rhythm. Optionally run `/audit` again for a final verification pass. Verify no primary screen looks materially rougher than the others.

## Close Criteria

- The app feels visually and tonally consistent across onboarding, first launch, Today, Review, and Settings.
- Existing flows communicate state clearly: users are not left guessing whether the app is loading, saving, enabled, disabled, or finished.
- Copy, spacing, and interaction feedback feel calm and intentional rather than mixed or accidental.
- No primary screen looks materially rougher or less considered than the others after the release.
- The release can be described honestly as polish and cohesion, not as a disguised feature release.
- No hard-coded `.foregroundStyle(.red)` or `.foregroundStyle(.white)` on app-branded primary surfaces; error and CTA styling use theme-derived values.
- Loading, empty, error, and success states have explicit, calm messaging where they exist.
- Alert and button labels avoid generic "OK" where a specific action label improves clarity.
- Manual verification on device: light mode, Dynamic Type, VoiceOver labels/focus, button disabled/loading states, touch targets, and visual rhythm.

## Implementation Handoff

- **Builders**:
  - Start with `/audit` on the four in-scope surfaces to establish a prioritized defect inventory; use findings to drive work but **do not** expand scope beyond in-scope polish dimensions.
  - Run `/polish` **per surface** after completing that surface's edits, not only once at the end. Use the polish skill checklist (visual alignment, typography, color, interaction states, copy, edge cases) as the verification step for each surface.
  - When a surface reveals clustered issues, use the narrowest relevant skill (`/arrange`, `/typeset`, `/clarify`, `/normalize`, `/harden`) first, then run `/polish` before moving on.
  - Finish with one final `/polish` pass across all surfaces; optionally run `/audit` again for verification.
- **frontend-design guidance**: Treat as taste and system-quality input; adapt to iOS and SwiftUI conventions instead of copying web/CSS patterns literally.
- **teach-impeccable**: Run only if `.impeccable.md` stops providing sufficient design context for future polish work. For 0.3.3, `.impeccable.md` is the approved source.
- **Test Lead**: Verify close criteria on device; validate that no behavior changes were introduced except intentional polish; check accessibility and state communication.

## Open Questions

- Whether 0.3.3 should remain explicitly light-mode-only (recommended: yes for this release; defer dark-mode token work).
- Whether the release should carry one visible changelog-worthy headline or ship as a broad cohesion pass only.
- Whether an explicit product terminology glossary is needed beyond what is already visible in app strings (defer unless copy normalization surfaces conflicts).

## Next Owner

`Builder`, then `Test Lead`, to execute the audit-first, surface-by-surface polish sequence (run `/audit` first, then `/polish` per surface, then final cross-surface verification), validate close criteria, and ensure the release reads as polish and cohesion rather than feature expansion.
