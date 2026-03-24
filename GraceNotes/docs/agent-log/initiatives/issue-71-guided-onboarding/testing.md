---
initiative_id: issue-71-guided-onboarding
role: Test Lead / QA
status: in_progress
updated_at: 2026-03-23
related_issue: 71
related_pr: 79
---

# Testing — PR #79 / guided onboarding

## Automated evidence (2026-03-23)

- **Destination**: `platform=iOS Simulator,name=iPhone 15,OS=17.5` (avoid `OS=latest` when no matching runtime is installed; Xcode may list both arm64 and x86_64 for the same simulator id).
- **Full scheme** (`xcodebuild … test`): **exit 0** — `GraceNotesTests` + `GraceNotesUITests` green on iPhone 15 / iOS 17.5. Occasional parallel-clone `FBSOpenApplicationServiceErrorDomain` log lines may still appear; the run still reported **TEST SUCCEEDED**.
- **Reconfirmed (QA reevaluation, same destination)**: **TEST SUCCEEDED** on 2026-03-23.
- **Fixes applied**: skip post–Seed full-screen cover under UI test (`ProcessInfo.graceNotesIsRunningUITests`); stable UI-test SwiftData store across `terminate()`/`launch()` (session key marker in `PersistenceController`); `configureUITestLaunch` before every app `launch()`; English locale launch args; gratitude chip ids `JournalGratitudeChip.*` for persistence assertions; `ReviewScreen` keeps list chrome when `ProcessInfo.graceNotesIsRunningUITests` and entries are empty; keyboard test re-taps gratitude after guided focus moves to Need; persistence test asserts `JournalGratitudeChip.0` on Today after relaunch (avoids flaky Review navigation).

## Manual smoke — post–Seed journey and guided path

**Reset (dev / QA)**

- Use Scheme → Run arguments: `-reset-journal-tutorial` (clears `JournalTutorialProgress` and `JournalOnboardingProgress` per `GraceNotesApp`).
- Delete app or clear container for a true fresh-install iCloud default check.

**Path A — Skip immediately**

1. Complete first-run welcome if shown; land on **Today**.
2. Add one gratitude, one need, one person (reach **Seed**). Confirm **Post-Seed** full-screen cover appears (no Seed unlock toast stacked per `JournalScreen` logic).
3. Tap **Skip** on the first page. **Expect**: cover dismisses; guided section locking no longer applies (`hasCompletedGuidedJournal`). **Suggestion cards** are **not** auto-dismissed by `completePostSeedJourney` — Reminders / AI / iCloud cards may still appear per `JournalOnboardingSuggestionEvaluator` until the user dismisses them or meets eligibility gates.

**Path B — Done after full pager**

1. Same through Seed; advance with **Next** through all pages; tap **Done** on last page. **Expect**: same completion flags as Path A.

**Path C — No post-seed shortcut to full guided rhythm**

1. From fresh state, dismiss or complete post-Seed journey as needed, then continue filling chips to Ripening / Harvest and notes/reflections to Abundance **without** relying on reading long copy. **Expect**: `JournalOnboardingFlowEvaluator` steps match unit tests (Gratitude → Need → Person → Ripening → Harvest → Abundance); focus moves per step when no field is focused.

**Accessibility / i18n (epic #71)**

- VoiceOver: post-Seed page indicator, primary actions, sample insights block.
- **zh-Hans**: spot-check `PostSeedJourney.`* and onboarding strings in app.

## Manual smoke — Settings deep links from journal suggestions

**Preconditions**

- Today entry; first Seed celebrated; suggestions not all dismissed; eligible suggestion per `JournalOnboardingSuggestionEvaluator` order (Reminders → AI → iCloud).

**Steps**

1. When a suggestion card appears, note title (localized keys map to reminders / AI / iCloud copy in `JournalScreen`).
2. Tap primary action. **Expect**: `openSettings(for:)` recomputes `currentSuggestion` and only proceeds if still eligible; Settings tab selected; scroll/highlight for `.reminders`, `.aiFeatures`, or `.dataPrivacy` per `settingsTarget(for:)`.
3. Return to Today; confirm no sticky wrong highlight after `clearSettingsTarget` consumption (exercise each target once).

