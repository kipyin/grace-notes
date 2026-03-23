---
initiative_id: issue-71-guided-onboarding
role: QA Reviewer
status: in_progress
updated_at: 2026-03-23
related_issue: 71
related_pr: (branch work; orientation 0.5.1 cohort)
---

# QA — Guided onboarding + 0.5.1 upgrade orientation

## Context

- **Strategist / Architect intent:** Onboarding / first-week orientation audit (locked: `0.5.1` anchor, one-time upgrade orientation, Seed branch below vs at/above Seed, no silent settings changes, new-install defaults off with UI recommendations).
- **Code reviewed:** `AppLaunchVersionTracker`, `MarketingVersion`, `JournalOnboardingProgress` (migration + `pending051*` branch), `GraceNotesApp` init order, `JournalScreen` (`evaluatePostSeedJourneyIfNeeded`, `completePostSeedJourney`, `postSeedJourneySkipsCongratulations`), `PostSeedJourneyView` (`skipsCongratulationsPage`), `ICloudSyncPreferenceResolver` onboarding key list.
- **Agent log:** [testing.md](testing.md) (updated 2026-03-23 to match suggestion behavior after post-Seed finish).
- **Automated evidence:** Full `xcodebuild test` green on `platform=iOS Simulator,name=iPhone 15,OS=17.5` (includes `Orientation051LaunchTests`, `MarketingVersionTests`).

## Requirement coverage

| Intent (locked plan) | Implementation | Verdict |
|----------------------|----------------|---------|
| Persist `lastLaunchedMarketingVersion`; first launch on `≥ 0.5.1` after `< 0.5.1` flags one-time upgrade cohort | `AppLaunchVersionTracker.applyLaunch` + `MarketingVersion.orientationReleaseAnchor` | **Met** |
| Run upgrade detection **before** migration closes guided journal | `GraceNotesApp.init`: `applyLaunch` then `resolvedHasCompletedGuidedJournal` | **Met** |
| Upgrade: defer `completedGuidedJournal` until Today level known; **below Seed** → full guided; **at/above Seed** → treat guided complete for chip path | `pending051GuidedJournalBranchResolution` + `resolvePending051GuidedJournalBranch` in `.task` | **Met** |
| Upgraders at/above Seed: orientation **without** Seed congratulations page | `postSeedJourneySkipsCongratulations = upgradePath && hasCompletedGuidedJournal` + `PostSeedJourneyView(skipsCongratulationsPage:)` | **Met** |
| One-time orientation for that upgrade (not every subsequent launch) | `pending051UpgradeOrientation` cleared in `completePostSeedJourney`; second launch `previous == 0.5.1` skips re-flag | **Met** |
| UITests / unit tests: do not spuriously flag upgrade | `!ProcessInfo.graceNotesIsRunningUITests` in `applyLaunch` | **Met** |
| Legacy welcome: upgraders who completed welcome **do not** re-see `OnboardingScreen` | Unchanged `@AppStorage(FirstRunOnboardingStorageKeys.completed)` — **by design** per plan | **Met (product)** |
| No **silent** flip of reminders / AI / iCloud preferences | Journey controls bind to `@AppStorage`; `completePostSeedJourney` only flips onboarding flags | **Met** |
| New keys + iCloud “continuity” policy | Keys listed in `ICloudSyncPreferenceResolver.onboardingKeys` | **Met** (heuristic continuity); see risks |

**Partial / product follow-up**

- **Installs with no stored prior marketing version** (e.g. very old build never writing the key): first 0.5.1 launch behaves like **first run** for cohort detection, **not** upgrade — Architect open question remains valid.
- **Multi-device / backup restore:** same as above; not code-verified here.

## Behavior and regression risks

| Risk | Severity | Notes |
|------|-----------|--------|
| `lastLaunchedMarketingVersion` absent on first 0.5.1 open | **Medium** | True upgraders from unversioned storage miss `pending051UpgradeOrientation`; acceptable only if product accepts “unknown prior = new cohort.” |
| `ICloudSyncPreferenceResolver` includes new onboarding keys | **Low–Med** | Increases “existing install” surface for default iCloud resolution; aligns with continuity goal; multi-device side effects need explicit product sign-off if KVS ever syncs these keys. |
| Post-Seed hidden under UITests | **Medium** | Real-user full-screen journey still **not** driven by UI tests; 0.5.1 skip-congrats path **untested** in UI automation. |
| `JournalScreen` orchestration | **Medium** | Many gates (`pending051`, `hasSeenPostSeedJourney`, completion level); unit tests cover tracker + branch resolution, not full `evaluatePostSeedJourneyIfNeeded` matrix. |
| Suggestions after Done/Skip | **Low** | Completing journey **does not** set `dismissed*` suggestion flags; cards may still appear — **correct** vs earlier doc typo; aligns with “no hidden dismiss.” |

## Code quality gaps

- `evaluatePostSeedJourneyIfNeeded` / `postSeedJourneySkipsCongratulations` deserve a **focused unit test** (pure logic) to lock the upgrade vs standard matrix.
- `JournalScreen` remains large; acceptable for now but increases merge conflict and review load.

## Test gaps

- No XCTest asserting **presentation** rules for post-Seed (standard vs upgrade, skip congrats).
- No automated test for `applyLaunch` when `previous` is missing but other legacy keys imply “old user” (if product wants that cohort).
- Manual matrix in Architect close criteria (0.5.0→0.5.1 below/above Seed, second launch, 0.5.1→0.5.2): **not** all reflected in [testing.md](testing.md) yet — **Test Lead** to extend checklist.

## Pass / fail recommendation

**Pass (implementation vs locked 0.5.1 onboarding intent)** — version gate, init order, Seed branch, skip-congrats path, and preference boundaries match the audit. Automated suite green on recorded simulator destination.

**Conditional for release:** Execute expanded **manual** matrix for upgrade cohorts; confirm **zh-Hans** for any new/changed copy; resolve **nil previous version** policy with Strategist if support tickets suggest missed orientations.

## Decision

- **Merge / CI (current tree):** **Pass** — objective test signal + code review above.
- **Ship / epic closure:** **Conditional** — manual 0.5.1 cohort matrix + localization.

## Open questions

- Should a **missing** `lastLaunchedMarketingVersion` on 0.5.1 first launch still classify as **upgrade** when strong legacy signals exist (e.g. `hasCompletedOnboarding`)?
- Do any onboarding keys need **explicit non-sync** documentation for multi-device?
- Add UI or unit tests for `evaluatePostSeedJourneyIfNeeded`?

## Next owner

- **Test Lead:** Extend [testing.md](testing.md) with 0.5.1 upgrade scenarios (below Seed / at Seed / above Seed / second launch); run and date.
- **Builder:** Optional `JournalScreen` evaluation logic unit tests.
- **QA Reviewer (follow-up):** Re-pass after manual matrix is ticked.
- **Release Manager:** Align `release-0-5-1-patch` checklist with this QA.
