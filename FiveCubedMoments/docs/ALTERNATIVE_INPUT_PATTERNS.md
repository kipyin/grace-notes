# Alternative Input Patterns for the "5s"

**Problem:** The current 5-slot layout (Gratitudes, Needs, People to Pray For) feels like a rigid list/form. We want the same *data* (5 items each) without the *list* feel.

---

## 4 Non-List Approaches

### 1. **Journal Prose** — "Fill in the sentence"
One flowing block of text with gentle placeholders. Feels like writing in a diary, not filling a form.

**Example:**
> I'm grateful for…  
> 1. ___ 2. ___ 3. ___ 4. ___ 5. ___

Or inline:
> Gratitudes: ___ · ___ · ___ · ___ · ___

**Pros:** Very cozy, narrative. Minimal visual structure.  
**Cons:** Parsing/editing individual items can be tricky; might need custom parsing.  
**Best for:** Warm Paper vibe.

---

### 2. **Chip / Tag Flow**
Items appear as removable chips (like tags or pills). User types in one field, taps "+" or presses Enter to add. Chips wrap in a flowing layout. Tap a chip to edit.

**Visual:** `[Family] [Health] [Coffee] [+ Add]` — soft rounded pills, wrap to multiple lines.

**Pros:** Organic, modern (similar to tag inputs). Easy to add/remove/reorder. No stacked rows.  
**Cons:** Slightly more interaction (add vs. type-in-place).  
**Best for:** Breath (minimal) or Warm Paper.

---

### 3. **Sequential Reveal** — One at a time
Show a single input. When user finishes and moves on (e.g., taps Next or presses Return), the next slot appears. Optionally show subtle progress (e.g., "2 of 5").

**Richer variant:** User types a *full sentence* → Enter → sentence is summarized into a short tag → tag appears as chip, input clears → next slot. Summarization can use LLMs or workarounds (colon syntax `Tag: sentence`, manual tag, truncation). See [Sequential Input Clarification](SEQUENTIAL_INPUT_CLARIFICATION.md).

**Pros:** Zero "list" feel. Focused, calming. Great for mindful journaling.  
**Cons:** Can't easily jump to edit #3 without stepping through.  
**Best for:** Breath, Tesseract-like immersion.

---

### 4. **Card / Sticky Note Grid**
Five small cards in a loose 2–3 column grid (or slightly overlapping). Each card is tappable; tap to expand into an edit field. Feels like sticky notes or index cards.

**Pros:** Tactile, playful. Breaks the vertical list. Very "cozy."  
**Cons:** More screen real estate; cards need to be compact.  
**Best for:** Warm Paper, Dribbble Cream aesthetic.

---

## Recommendation

| Pattern | Warm Paper fit | Breath fit | Implementation |
|---------|----------------|------------|----------------|
| Journal Prose | ★★★ | ★★ | Medium (custom parsing) |
| Chip Flow | ★★★ | ★★★ | Easy (standard pattern) |
| Sequential | ★★ | ★★★ | Easy |
| Card Grid | ★★★ | ★ | Medium |

**Suggested combo:** Start with **Chip Flow** for Gratitudes/Needs/People — it removes the list feel while keeping the structure. Optionally pair with **Journal Prose** for a hybrid (e.g., prose for gratitudes, chips for needs).

---

## Mockups

See `docs/mockups/` for:
- `concept-1-warm-paper-chips.html` — Warm Paper + Chip Flow
- `concept-1-warm-paper-prose.html` — Warm Paper + Journal Prose
- `concept-1-warm-paper-sequential.html` — Warm Paper + Sequential Reveal
