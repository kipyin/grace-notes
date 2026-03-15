# Sequential Input — Clarification & Workarounds

## Your Understanding (Confirmed ✓)

You're describing a **richer** sequential flow:

1. User types a **full sentence** (e.g., "I'm so grateful for my family's support today")
2. User hits **Enter**
3. The sentence is **summarized** into a short tag (e.g., "Family")
4. The tag appears as a chip; input **clears**
5. User types the next sentence (slot 2), and so on

The original mockup was simpler: *type something → hit enter → it becomes a chip* (no summarization). Your version supports **full reflective writing** while keeping the UI clean with short tags. The summarization step is the hard part (LLMs, cost, latency, offline).

---

## Workarounds (No LLM)

### 1. **Colon syntax** — `Tag: Full sentence`

User types: `Family: I'm so grateful for my family's support today`

- **Before colon** → becomes the tag ("Family")
- **After colon** → stored as full text (optional; could be hidden in detail view)
- On Enter: tag chip appears, input clears

**Pros:** No ML. User controls the tag. Full text preserved.  
**Cons:** Slightly more typing; requires learning the pattern.  

**Variants:**
- `Tag | sentence` (pipe separator)
- `#Family I'm grateful...` (hashtag-style)

---

### 2. **Manual tag** — User selects/types tag while or after writing

**Option A: Inline after typing**  
User types the full sentence, hits Enter. A small popover or inline control appears: "Add a short label?" with a text field or quick-pick suggestions (e.g., first word, first 2 words). User confirms or edits.

**Option B: Two-phase**  
1. User types sentence → hits Enter  
2. Full text is saved as-is; a second field appears: "Label (optional): ___"  
3. User types "Family" or leaves blank → stored as full text only  

**Option C: Tap to tag**  
Completed items show as expandable chips. Tap to expand → see full sentence, tap "Edit tag" to add/change the short label.

---

### 3. **First-N-words** — Rule-based "summary"

On Enter, take the first 1–3 words as the tag (e.g., "I'm so grateful" → "I'm so grateful" or "I'm"). Simple but often clunky. Better: **first noun** or **last phrase** heuristics (harder, no LLM).

---

### 4. **Full text only, no tag**

Store the full sentence. In the chip/UI, show a truncated preview (e.g., first 20 chars + "…"). Tap to expand and read the full text. No summarization at all — just truncation for display. Simplest; works offline.

---

### 5. **Hybrid: Colon optional**

- If user types `Tag: sentence` → use Tag as label, sentence as full text  
- If user types `sentence` only → use first N words or truncation as display label, full text stored  

User can opt into the colon pattern when they want a custom tag.

---

## Summary

| Approach | LLM? | UX | Data |
|----------|------|-----|------|
| Colon `Tag: sentence` | No | Learn once | Tag + full text |
| Manual tag (after) | No | Extra step | Tag + full text |
| First-N-words | No | Often odd | Full text, display = truncation |
| Full text only | No | Simplest | Full text, display = truncate |
| LLM summarization | Yes | Best | Tag + full text |

**Recommendation:** Start with **colon syntax** (1) — it's explicit, no ML, and preserves full text. Add **manual tag** (2) as an alternative for users who forget or prefer to write first, tag later.
