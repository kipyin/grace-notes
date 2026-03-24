# Issue #39 — Chip cloud prompts (initiative brief)

## Context

GitHub issue #39: fine-tune AI prompts for chips; deterministic path already shipped (see CHANGELOG 0.3.1 / PR #47).

## Decision

- **Instruction locale:** Chip cloud prompts follow the same rule as Review insights: `AppInstructionLocale.preferred(bundle:)` → Simplified Chinese for `zh-Hans`, English otherwise (`AppInstructionLocale.swift`). `CloudSummarizer` accepts `ChipCloudPromptLanguage` (`.automatic` default) and optional `bundleForAutomaticLanguage` for tests.
- **Low-signal input:** Skip the network call for obvious keyboard mash (long Latin, no spaces, low vowel ratio) or a single repeated character (≥4); use the injected/default deterministic fallback (trimmed literal).
- **Model output:** After a successful API response, reject labels that fail **grounding** in the user text or match **generic spiritual filler** phrases not present in the entry (e.g. 心存感激, thankful/gratitude when absent from input); then use the same fallback as API failure.
- **#69:** Chip unit-budget “skip cloud” optimization remains separate; any future merge of skip conditions should live in one place in the summarizer stack.

## Open Questions

- Emoji-only or mixed-script entries: keep sending to the model unless a new heuristic is product-approved.
- Additional locales: default to English instructions until localized prompts exist.

## Next Owner

- **Builder / QA:** Monitor real API behavior; tune banned phrase list or heuristics if false positives appear.
- **Architect:** If #69 adds another pre-flight skip, consolidate with `shouldSkipCloudForLowSignal` behind one policy function.
