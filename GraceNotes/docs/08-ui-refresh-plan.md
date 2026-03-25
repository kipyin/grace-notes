# Grace Notes UI Refresh Plan

Date: 2026-03-25

**Status:** Design and implementation plan only. No UI changes are included in this document.

---

## Goal

Make Grace Notes feel less like a themed document editor and more like a calm, distinctive daily reflection product with its own visual language.

The target is not "more decorative." The target is:

- more ownable
- more intentional
- more polished
- still calm, warm, and emotionally safe

This plan follows the approved design context in `.impeccable.md`:

- calm, warm, supportive
- light-mode-first
- paper-like, readable, low-pressure
- not gamified
- not dashboard-like
- not noisy or performative

---

## Core problem

Grace Notes already has a coherent theme, but the theme is currently expressed more through color and typography than through structure.

Today the app still reads as:

- a standard iOS shell with custom colors
- a set of grouped sections and cards
- a journaling form with fields

Instead of reading as:

- a guided daily ritual
- a reflection companion
- a product with a recognizable point of view

### Current strengths to preserve

- Warm paper palette in `DesignSystem/Theme.swift`
- Serif-led reading tone across reflective content
- The growth model: `Soil`, `Seed`, `Ripening`, `Harvest`, `Abundance`
- Calm feedback and restrained motion
- Low-pressure interaction model

### Current issues creating the "document" feeling

1. The app shell still relies heavily on default iOS affordances.
2. Too many surfaces use the same rounded card + light border treatment.
3. Today is structured like a tidy form rather than a ritualized writing flow.
4. Review feels like a feature tab with controls and lists, not a weekly digest.
5. Visual hierarchy is consistent but too even; too many elements speak at the same volume.

---

## North star direction

The app should move toward:

**Quiet editorial ritual**

That means:

- editorial rather than utilitarian
- tactile rather than "app chrome" heavy
- guided rather than form-like
- memorable because of composition and metaphor, not ornament

### Signature idea

Make the growth metaphor the app's visual signature.

The `Soil -> Seed -> Ripening -> Harvest -> Abundance` path is the most ownable concept in the product. It should become more than a badge label. It should shape:

- page hierarchy
- section emphasis
- progress affordances
- onboarding structure
- review framing
- subtle animation moments

The user should feel they are moving through a gentle path, not filling in a template.

---

## Design principles for the refresh

## 1. Ritual over form

The user should feel invited into a daily moment, not presented with a blank productivity sheet.

Implications:

- stronger top-of-screen moment on Today
- fewer visible container boundaries competing for attention
- clearer emphasis on the next meaningful action

## 2. Growth path over generic progress UI

The completion system should feel reflective and organic, not gamified.

Implications:

- keep the named levels
- avoid trophy-like or streak-like visual language
- use progression as orientation, not pressure

## 3. Editorial digest over control-heavy review

Review should feel like a weekly reading experience.

Implications:

- stronger hero insight
- clearer narrative structure
- timeline secondary, not equal-weight with insights

## 4. Product shell over default app chrome

The app should feel designed from the first glance.

Implications:

- more intentional tab identity
- better title treatment
- less dependence on stock symbols that imply "document" or "settings utility"

## 5. Surface hierarchy, not surface repetition

Not every piece of content should live inside the same rounded rectangle.

Implications:

- reserve bordered paper surfaces for true inputs or key panels
- let guidance, summaries, and supporting copy breathe outside cards when possible
- create a more varied rhythm between open content and contained content

---

## Proposed visual language

## 1. Shell

### Desired feel

The shell should feel soft and authored, not purely system-default.

### Changes

- Revisit tab icons in `Application/GraceNotesApp.swift`, especially `Today`.
- Avoid icons that imply files or utilities.
- Make tab labels feel like product destinations, not feature buckets.
- Increase distinction between page background and navigation/tab chrome.
- Consider a more custom-feeling top title treatment on major screens, especially Today and Review.

### Recommendation

Short term:

- replace `doc.text` on Today with a symbol that implies presence, reflection, or the current day rather than a document
- keep native `TabView`, but refine its semantics and supporting styling

Longer term:

- consider a lightly customized tab presentation if the standard tab bar continues to make the product feel generic

---

## 2. Surfaces

### Current issue

The app overuses the same paper card treatment across:

- onboarding
- suggestions
- tutorial hints
- Today sections
- Review panels
- settings sections

### New hierarchy

Define three surface roles:


| Surface role      | Use for                                       | Visual treatment                                            |
| ----------------- | --------------------------------------------- | ----------------------------------------------------------- |
| **Canvas**        | page background and open reading space        | warm, lightly tinted background; minimal borders            |
| **Paper**         | important narrative blocks and summaries      | soft fill, subtle edge, optional texture, larger spacing    |
| **Input surface** | text fields, editors, editable chips, toggles | clearer border, stronger affordance, most tactile treatment |


### Rule

If a view is not directly editable, it should not automatically get the same treatment as an input.

---

## 3. Typography

### Current issue

The font choices are directionally good, but the role contrast is still too soft.

### Proposed system

- Serif remains the voice of reflection, meaning, and narrative.
- Sans remains the voice of controls, utility, metadata, and navigation.

### Suggested role mapping


| Role                                        | Recommended direction                                   |
| ------------------------------------------- | ------------------------------------------------------- |
| Page moments and reflective statements      | serif                                                   |
| Section titles on Today                     | serif, but less card-like and more spatially integrated |
| Navigation, tabs, controls, settings labels | sans                                                    |
| Metadata, dates, supporting labels          | quieter sans or smaller serif depending on context      |


### Practical effect

Today and Review should feel more like something to read and enter, while Settings remains operational and straightforward.

---

## 4. Color and texture

### Keep

- warm cream backgrounds
- terracotta accent
- muted text
- soft green / warm progression states

### Add

- more separation between page canvas and editable surfaces
- slightly deeper tier-specific tones for the completion states
- subtle texture or grain in the broadest page backgrounds or key paper surfaces

### Avoid

- high-contrast gradients
- glossy glow-heavy styling
- dark-mode-first drama
- overly saturated success colors

Texture should be felt, not noticed.

---

## 5. Motion

### Keep

- short, calm transitions
- completion feedback as supportive acknowledgment
- reduced-motion respect

### Add

- staged entrance on key screens
- section emphasis changes when editing begins
- softer reveal of contextual guidance and review summaries

### Avoid

- bouncy or playful animation curves
- ornamental motion on every interaction
- anything that feels gamified or reward-loop driven

Motion should support ritual and focus, not novelty.

---

## Screen-by-screen plan

## 1. Today

**Primary files:**

- `Features/Journal/Views/JournalScreen.swift`
- `Features/Journal/Views/DateSectionView.swift`
- `Features/Journal/Views/SequentialSectionView.swift`
- `Features/Journal/Views/EditableTextSection.swift`
- `Features/Journal/Views/JournalCompletionPill.swift`

### Current read

Today is calm and functional, but structurally it reads as:

- date/status block
- suggestion cards
- three repeated chip-input sections
- two repeated text sections

This is clear, but it feels like a form stack.

### Desired read

Today should feel like entering a daily page with one active reflection flow.

### Proposed hierarchy

#### A. Ritual header

Turn the top of the screen into a distinct moment:

- date as a quiet anchor
- completion state as a branded growth marker
- one short line of contextual tone or reflection framing
- stronger sense that the user is "arriving" somewhere

`DateSectionView.swift` and `JournalCompletionPill.swift` already contain the seeds of this. This should become the first signature area of the app.

#### B. Active writing stage

Instead of rendering all sections as equivalent modules, create a stronger active/passive hierarchy:

- the current editable area feels open and alive
- completed or inactive areas recede
- guidance appears near the active step, not as another card competing for attention

This can be done without hiding sections; it is mainly a hierarchy and spacing problem.

#### C. Chip lanes feel like collected fragments, not mini cards

In `SequentialSectionView.swift`, the chips and input should read as part of a continuous writing lane.

Move toward:

- more ribbon-like horizontal lanes
- less card framing around the entire section
- stronger distinction between chips and the active input
- clearer section individuality without changing the data model

#### D. Long-form notes feel like page areas

`EditableTextSection.swift` should feel less like another repeated block and more like a writing area near the bottom of the page.

Desired shift:

- more breathing room before notes/reflections
- less "another section card"
- more page-like vertical rhythm

### Specific changes

- Reduce the number of fully bordered section wrappers visible at once.
- Make section headers more spatial and less boxed.
- Rework onboarding suggestion and tutorial hint placement so they feel integrated, not inserted as unrelated cards.
- Use completion progression to lightly influence emphasis and color.
- Strengthen top-of-screen identity before the first input.

### Acceptance intent

- Today should feel like a single composed screen, not stacked modules.
- The next meaningful writing action should be obvious within 2 seconds.
- Completion and guidance should feel encouraging, not supervisory.

---

## 2. Review

**Primary files:**

- `Features/Journal/Views/ReviewScreen.swift`
- `Features/Journal/Views/ReviewSummaryCard.swift`

### Current read

Review currently feels like:

- a mode picker
- an insight card
- a timeline list

It is understandable, but still resembles a feature/settings surface more than a reflective digest.

### Desired read

Review should feel like opening a weekly letter to yourself.

### Proposed hierarchy

#### A. Hero insight first

When there are insights, the screen should open on the primary insight itself, not on a control.

That means:

- promote the lead observation
- reduce the visual prominence of the mode toggle
- give the first screenful a clear reading order

#### B. Narrative structure

The current "This week / A thread / A next step" structure is good. The visual composition should make it feel more editorial:

- one hero block
- one supporting thread
- one gentle next step
- activity and recurring themes as evidence, not equal-weight content

#### C. Timeline becomes secondary

The timeline should remain valuable, but it should read like an archive or appendix below the digest, not as a parallel main mode fighting for attention.

Short-term:

- keep the segmented control, but visually quiet it down
- make Insights unmistakably the primary mode

Longer-term:

- consider whether Timeline belongs as a sub-section within Review rather than a peer mode

### Specific changes

- Increase contrast between hero insight and support blocks.
- Reduce "list row in a list" feeling around insights.
- Make source/status information less visually noisy.
- Reframe empty and loading states to feel like part of the review ritual.
- Make timeline rows feel like a calm archive, not settings rows.

### Acceptance intent

- The first screenful of Review should immediately communicate weekly meaning.
- Insights should feel authored and worth reading.
- Timeline should support memory lookup without flattening the screen into another list UI.

---

## 3. Onboarding and post-Seed journey

**Primary files:**

- `Features/Onboarding/OnboardingScreen.swift`
- `Features/Journal/Tutorial/PostSeedJourneyView.swift`
- `Features/Journal/Tutorial/PostSeedJourneyView+Pages.swift`
- `Features/Journal/Tutorial/JournalOnboardingSuggestionView.swift`
- `Features/Journal/Tutorial/JournalTutorialHintView.swift`

### Current read

These flows are coherent with the theme, but they mostly reuse the same app card language.

### Desired read

These surfaces should feel slightly more ceremonial than the main app:

- more arrival
- more narrative spacing
- less repeated "paper card" treatment

### Specific changes

- Give the first onboarding screen one memorable visual gesture instead of a single card and CTA.
- Let the path model in post-Seed onboarding feel more like a branded journey artifact.
- Reduce the sense that suggestion banners are just settings prompts inside Today.
- Differentiate hint, suggestion, and onboarding moments by role, not only by copy.

### Acceptance intent

- Onboarding should feel like entering a product world, not a checklist.
- Post-Seed guidance should deepen the metaphor, not just explain features.

---

## 4. Settings

**Primary file:**

- `Features/Settings/SettingsScreen.swift`

### Current read

Settings is clear and usable, but still shares too much visual DNA with Review and Today.

### Desired read

Settings should feel quieter and more operational than the reflective surfaces.

### Specific changes

- Keep settings practical and low-friction.
- Use more open list rhythm and less paper-card emphasis where possible.
- Preserve authored title case and calm copy.
- Make supportive guidance feel trustworthy, not promotional.

### Acceptance intent

- Settings should feel intentionally simple, not visually under-designed.
- It should clearly belong to the same app without competing with Today and Review for emotional tone.

---

## Component strategy

## 1. Elevate `JournalCompletionPill`

This should become the strongest recurring branded component in the product.

Current role:

- a useful completion chip

Target role:

- the visual anchor of the growth model
- a bridge between Today, Review, and onboarding

Potential expansions:

- related tier accents
- shared transitions into educational or review surfaces
- more differentiated level-specific presence

---

## 2. Break up `SequentialSectionView`

`SequentialSectionView.swift` currently does a lot:

- guidance
- section heading
- progress dots
- chip lane
- add-chip affordance
- input
- loading/update overlay

For design iteration, split conceptually into smaller visual roles:

- section heading / status
- chip lane
- draft input
- onboarding guidance treatment

This does not require a new architecture first, but the visual system will be easier to evolve if these concerns are less bundled.

---

## 3. Differentiate informational versus editable UI

Create a clearer divide between:

- things to read
- things to tap
- things to type into

At the moment those roles sometimes look too similar.

This should be addressed through:

- surface role tokens
- typography roles
- spacing rhythm
- border usage

---

## 4. Introduce a small set of reusable visual primitives

Recommended additions to the design system:

- page canvas background rules
- paper surface variants
- input surface variants
- section spacing presets
- signature path/progression accents
- calmer empty/loading state treatments

This should live near `DesignSystem/Theme.swift` and related shared modifiers, not be re-invented per screen.

---

## Implementation phases

## Phase 1: Establish visual language on Today

**Why first**

Today is the core loop and the strongest chance to change the product's first impression.

**Scope**

- redesign top-of-screen ritual header
- reduce card repetition
- improve active-section hierarchy
- reframe long-form areas

**Primary files**

- `JournalScreen.swift`
- `DateSectionView.swift`
- `SequentialSectionView.swift`
- `EditableTextSection.swift`
- `Theme.swift`

---

## Phase 2: Reframe Review as a digest

**Why second**

Review is the second-biggest product identity surface after Today.

**Scope**

- hero insight hierarchy
- quieter mode control
- richer digest composition
- calmer timeline presentation

**Primary files**

- `ReviewScreen.swift`
- `ReviewSummaryCard.swift`
- `Theme.swift`

---

## Phase 3: Align onboarding and supporting surfaces

**Why third**

Once the core product language is established, onboarding and hints can be made consistent with it.

**Scope**

- onboarding arrival feel
- post-Seed journey styling
- suggestion and hint role differentiation

**Primary files**

- `OnboardingScreen.swift`
- `PostSeedJourneyView.swift`
- `PostSeedJourneyView+Pages.swift`
- `JournalOnboardingSuggestionView.swift`
- `JournalTutorialHintView.swift`

---

## Phase 4: Shell and final polish

**Why last**

The shell should reflect the final language, not a moving target.

**Scope**

- tab icon and label refinement
- title treatment
- final spacing and motion pass
- empty/loading/error state alignment

**Primary files**

- `GraceNotesApp.swift`
- `AppInterfaceAppearance.swift`
- cross-app polish on touched screens

---

## Design acceptance checklist

The refresh is successful when:

- A new user would not describe the app as "a journaling form" in the first minute.
- Today has one obvious focal area and a clearer sense of ritual.
- Review feels like a weekly digest, not a utility screen.
- The growth path feels like Grace Notes' own visual signature.
- The app uses fewer generic bordered cards without losing clarity.
- Settings still feels simple and trustworthy.
- Motion remains calm and accessible.

---

## Risks and guardrails

## Risks

- Over-correcting into something too decorative
- Accidentally gamifying the completion path
- Making Today less efficient while trying to make it more beautiful
- Creating visual inconsistency by redesigning one screen in isolation

## Guardrails

- Keep editing fast and obvious.
- Keep Dynamic Type, VoiceOver, reduce motion, and contrast support intact.
- Prefer compositional changes over ornamental layers.
- Preserve emotional safety and low-pressure tone.

---

## Open questions before implementation

1. Should Review remain a two-mode surface, or should Timeline become subordinate to Insights?
2. How far should the shell move away from default iOS chrome without harming familiarity?
3. Should the growth metaphor appear only in status moments, or more directly in section layout?
4. Is subtle paper texture worth the added implementation and performance cost on lower-end devices?

---

## Recommended next step

If this plan is approved, the best next implementation sequence is:

1. Create a small visual direction issue for Today that references this document.
2. Implement Phase 1 only, without touching Review in the same PR.
3. Validate the new Today hierarchy on device before spreading the language elsewhere.
4. Use that result to drive the Review redesign in a follow-up PR.

