# Review Insight Quality Contract (Grace Notes)

Date: 2026-03-17

## Purpose of the Review page (with or without AI)

The Review page exists to make reflection **compound over time**.

It should help users:
1. Notice recurring patterns across Gratitudes, Needs, and People in Mind.
2. Receive calm, trustworthy reflection language grounded in their own entries.
3. Carry momentum forward through one gentle continuity question.

AI is optional. On-device deterministic insights are the baseline product behavior.

**GitHub tracking:** **#40** covers an **insight-first presentation** redo on Review → Insights. **#80** covers **deeper generation** work (prompts, sanitizer, fixture audits, tests) to reduce generic output against this contract.

---

## Review period

Insights (on-device and cloud) use the **seven calendar days ending on the reference day** (usually “today” in the user’s local calendar): from `startOfDay(reference) − 6 days` through the end of that reference day, half-open as `start..<end` in code. The prior seven days are used only for comparison-style patterns (e.g. continuity shifts). This is **not** an ISO or locale “calendar week.”

---

## Definition: what is a “good insight” in Grace Notes

A good insight must be:

1. **Specific** — references concrete content from the review period (themes, people, counts, or that window’s context).
2. **Faithful** — does not invent facts beyond available entries.
3. **Calm** — non-judgmental, low-pressure tone.
4. **Continuity-oriented** — includes one clear next-step prompt or question.
5. **Scannable** — short and readable in one card pass.
6. **Transparent** — source label is visible (`AI` or `On-device`).
7. **Gently connective** — when the review period supports it, prefer one safe, concrete relationship between two recurring signals instead of a broad summary that tries to cover everything.

If an AI payload fails quality checks, fallback to deterministic output.

Do not force a connection when evidence is thin. The product should prefer a smaller, faithful insight over a clever one.

## Low-entry handling

If the selected review period contains fewer than **3 meaningful entries**, skip the cloud AI path and show the deterministic on-device insight instead.

Rationale:
- thin periods are more likely to produce speculative or generic AI language
- the on-device path is the more trustworthy baseline when evidence is limited

Expectation:
- low-entry periods should still feel calm, specific, and useful
- the visible source label should remain accurate (`On-device`)

---

## Sample weeks and expected-quality insights

## Week A — “Tired but steady”

### Sample signals
- Gratitudes: `morning sunlight (3)`, `daughter’s laughter (2)`, `coffee with spouse (2)`
- Needs: `rest (4)`, `focus time (3)`, `boundaries (2)`
- People in mind: `Mia (3)`, `Daniel (2)`

### Good insight example
- Narrative: “This week you kept returning to family moments while also naming a strong need for rest and focus.”
- Resurfacing: “You mentioned **rest 4 times** this week.”
- Continuity: “What one boundary could protect 30 minutes of rest tomorrow?”

## Week B — “Care for others + emotional load”

### Sample signals
- Gratitudes: `neighbor check-ins (2)`, `prayer time (3)`
- Needs: `patience (3)`, `emotional margin (2)`
- People in mind: `Mom (4)`, `Alex (3)`

### Good insight example
- Narrative: “Your week centered on caring presence, especially for Mom, while you asked for patience and emotional margin.”
- Resurfacing: “You kept **Mom in mind 4 times** this week.”
- Continuity: “What is one gentle way to support Mom this weekend without draining yourself?”

## Week C — “Low-entry week”

### Sample signals
- Entries only on 2 days
- Needs include `sleep`, `clarity`; no strong recurring people theme

### Expected path
- Use the deterministic on-device insight.
- Do not call the cloud AI path for this period.

### Good insight example
- Narrative: “You showed up for reflection on two days this week and named simple anchors: rest and clarity.”
- Resurfacing: “You returned to rest-related needs this week.”
- Continuity: “What would make tomorrow’s check-in easy to start?”

---

## Technical contract

## Input
- Journal entries whose `entryDate` falls in the current review period (up to a bounded context window for the cloud path).
- Structured request contract sent to cloud model.

## Required output shape
```json
{
  "narrativeSummary": "string",
  "resurfacingMessage": "string",
  "continuityPrompt": "string",
  "recurringGratitudes": [{"label":"string","count":number}],
  "recurringNeeds": [{"label":"string","count":number}],
  "recurringPeople": [{"label":"string","count":number}]
}
```

## Quality gates
1. Parse robustness:
   - Accept raw JSON and fenced JSON payloads.
2. Structural validity:
   - Required keys present and decodable.
3. Theme sanitation:
   - Non-empty labels, positive counts, bounded list length.
4. Message sanitation:
   - Trimmed, non-empty fallback behavior, max-length clamp.
5. Anti-generic checks:
   - Replace generic continuity language with theme-specific prompts when themes are available.
6. Specific resurfacing:
   - Prefer explicit recurring-theme resurfacing copy tied to counts.
7. Thin-evidence guard:
   - If fewer than 3 meaningful entries exist in the review period, do not call the cloud AI path.

If any hard gate fails, throw and allow provider-level deterministic fallback.

---

## Success criteria for implementation

- Review insights remain meaningful when AI is off.
- AI-on results are consistently more specific than generic motivational copy.
- Users can explain “why this insight was shown” by mapping it to their entries in the review period.
- Low-entry periods resolve through deterministic fallback rather than speculative AI output.
