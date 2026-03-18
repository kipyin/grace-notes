# Grace Notes — Design Spec

**Final design:** Warm Paper theme + Sequential input with Natural Language summarization.

---

## 1. Theme: Warm Paper

Cream and earth tones — cozy, tactile, morning-coffee feel.

| Element | Spec |
|---------|------|
| **Background** | Cream (#F8F4EF), warm paper (#F5EDE4) |
| **Text** | Charcoal (#2C2C2C), muted brown (#5C5346) for secondary |
| **Accent** | Terracotta (#C77B5B), sage green (#8B9A7D) for completed states |
| **Inputs** | Rounded (14–16pt), light border, soft focus state |
| **Typography** | Serif for headers (Playfair Display), Source Serif for body |

---

## 2. Input: Sequential (One at a time)

For Gratitudes, Needs, and People To Pray For:

1. User types a **full sentence** in a single input
2. User hits **Enter**
3. Sentence is **summarized** into a short tag (chip)
4. Tag appears as chip; input **clears**; next slot ready
5. Repeat until 5 items per section

**Assumption:** Gratitudes, needs, and people each have a maximum of 5 items (`JournalEntry.slotCount`). The ViewModel and UI enforce this limit.

---

## 3. Summarization into Chips

### Primary: Natural Language (on-device)

Use Apple's **Natural Language** framework (`NLTagger`, `NLTokenizer`) to extract keywords/nouns from the sentence as the chip label. Works offline, no API cost, privacy-preserving.

### Fallback: First N words (with fading)

When NL extraction fails or returns nothing useful, use the first N words of the sentence as the display label. Chip shows truncated text with a **gradual fade-out** at the right edge (e.g., mask or gradient) to indicate truncation. Full sentence is always stored; chip display is abbreviated.

### Future: Cloud API

Architecture should allow swapping or augmenting the summarizer with a cloud LLM (OpenAI, Anthropic, etc.) in a future release. Abstract the summarization behind an interface so NL vs API can be selected by user preference or availability.

---

## 4. Chip Display

- **NL or API tag:** Short label (1–3 words) shown in full
- **First-N fallback:** First N words with **gradual fade** (e.g., linear gradient from opaque to transparent at the right edge), max width or char limit
- **Tap chip:** Expand to view/edit full sentence

---

## 5. Mockup

`archive/2026-03-mockups/design-mockup.html` — Warm Paper + Sequential layout. Screenshot: `archive/2026-03-mockups/screenshots/design-mockup.png`.
