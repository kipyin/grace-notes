# Grace Notes Review Insights: Examples + Technical Spec

Date: 2026-03-17

This document captures:
1. product-quality examples of "good insights",
2. technical language for implementation requirements.

See also: `03-review-insight-quality-contract.md` for the full contract.

## 1) Product purpose

The Review page is designed to make reflection compound over time:
- detect recurring patterns,
- mirror them back calmly,
- and suggest one continuity prompt.

AI is optional. On-device deterministic insights are baseline behavior.

## 2) Good insight examples from sample weeks

## Sample Week A — Tired but steady
- Signals:
  - Gratitudes: sunlight (3), daughter’s laughter (2), coffee with spouse (2)
  - Needs: rest (4), focus time (3), boundaries (2)
  - People: Mia (3), Daniel (2)
- Good output:
  - Narrative: "This week you kept returning to family moments while also naming a strong need for rest and focus."
  - Resurfacing: "You mentioned rest 4 times this week."
  - Continuity: "What one boundary could protect 30 minutes of rest tomorrow?"

## Sample Week B — Care for others + emotional load
- Signals:
  - Gratitudes: neighbor check-ins (2), prayer time (3)
  - Needs: patience (3), emotional margin (2)
  - People: Mom (4), Alex (3)
- Good output:
  - Narrative: "Your week centered on caring presence, especially for Mom, while you asked for patience and emotional margin."
  - Resurfacing: "You kept Mom in mind 4 times this week."
  - Continuity: "What is one gentle way to support Mom this weekend without draining yourself?"

## Sample Week C — Low-entry week
- Signals:
  - Entries on 2 days only
  - Needs include sleep and clarity
- Good output:
  - Narrative: "You showed up for reflection on two days this week and named simple anchors: rest and clarity."
  - Resurfacing: "You returned to rest-related needs this week."
  - Continuity: "What would make tomorrow’s check-in easy to start?"

## 3) Technical quality requirements

Every insight payload must satisfy:
- Specificity: reference concrete themes/people/counts where available.
- Faithfulness: no invented facts.
- Tone: calm, non-judgmental.
- Continuity: one clear next-step question.
- Scannability: bounded length, readable card copy.
- Transparency: explicit source label (`AI` or `On-device`).

## 4) Implementation checklist

- Prompt contract:
  - include anti-generic instruction,
  - require theme-grounded narrative when themes exist,
  - require specific continuity prompt.
- Parsing robustness:
  - parse raw JSON and fenced JSON.
- Sanitization:
  - trim and clamp messages,
  - remove invalid themes,
  - replace generic continuity phrasing with theme-specific fallback when possible.
- Fallback:
  - if AI payload decode or quality checks fail, return deterministic insights.
