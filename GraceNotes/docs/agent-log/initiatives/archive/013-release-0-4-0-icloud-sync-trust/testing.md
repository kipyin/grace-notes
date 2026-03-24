# Testing: 0.4.0 iCloud sync trust slice

## Automated (Linux / CI)

- `PersistenceRuntimeSnapshotTests` — factory combinations; `test_makeInMemoryForTesting_matchesFactory` **skipped on iOS Simulator** (second `ModelContainer` in hosted test app hits malloc crash).
- `JournalDataImportServiceTests` — decode, schema rejection, **import payload size / max entry count** guards, dedupe-by-day, sanitize on Simulator; SwiftData import paths **skipped on Simulator** (same hosted crash class).
- `AISettingsCloudStatusModelTests` — `test_misconfiguredWhenKeyMissing` is **async** so `@MainActor` model updates do not corrupt heap on Simulator.

**Evidence (macOS):** Full `xcodebuild test` — scheme **GraceNotes** (not Demo), destination `iPhone 17` / iOS 26.3.1 Simulator, 2026-03-20 — **TEST SUCCEEDED**.

- `ICloudAccountStatusMappingTests` — `CKAccountStatus` → `ICloudAccountBucket` mapping and `showsICloudSyncToggle` per bucket (requires CloudKit SDK available to test bundle; same as host platform). *Evidence (macOS):* `xcodebuild … -only-testing:GraceNotesTests/ICloudAccountStatusMappingTests test` on iPhone 17 Simulator (iOS 26.3.1), 2026-03-20 — **TEST SUCCEEDED** (includes `test_showsICloudSyncToggle_perBucket`). Linux agents cannot compile these tests.

## Manual (macOS, signed build / Simulator)

Cross-link matrix: [`architecture.md`](architecture.md).

| Check | Steps | Expected |
|-------|--------|----------|
| Fallback copy | Airplane mode or revoke CloudKit until disk open fails then succeeds locally | Primary states local-only session; no “synced across devices” implication; secondary fallback message; recovery text if applicable |
| Toggle + relaunch | Flip iCloud sync; force-quit; reopen | Store mode matches toggle after relaunch; secondary “aligned” when toggle matches effective store |
| Account fetch | Open Settings tab | Account row moves from “Checking…” to resolved; toggle remains visible while “Checking…” |
| Hidden toggle (signed out / restricted) | Simulator or device with no iCloud account (or restricted) | No iCloud sync toggle; **Open Settings** still shown for `noAccount` / `restricted`; secondary/footer use stored-preference wording (no VoiceOver “sync switch” when toggle absent); preference row stays honest if sync was left on but account is gone (no promise of in-app off) |
| Layout on bucket resolve | Open Settings; wait for account row | Row count may drop by one when toggle hides after resolve (acceptable); export and primary rows unchanged |
| Dynamic Type | Largest categories | Status block readable; toggle/export remain tappable (`minHeight` 44) when visible |

Full CloudKit validation remains **device/signed** environment only; see root `AGENTS.md`.
