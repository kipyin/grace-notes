# Initiative: 0.4.0 iCloud sync trust (Settings truthfulness)

Normative **state matrix** for user-visible copy (no cross-device guarantee when local fallback is in use):

| `startupUsedCloudKitFallback` | `storeUsesCloudKit` | Primary intent |
|------------------------------|---------------------|----------------|
| `true` | `false` | Local-only for this session; do **not** imply multi-device sync. |
| `false` | `true` | Cloud-backed store opened successfully on this device. |
| `false` | `false` | Local-only store (preference off or equivalent). |

**Honest sync ceiling:** Settings reflects **this launch’s** effective store (`PersistenceRuntimeSnapshot` from `PersistenceController`) plus the current `@AppStorage` toggle for **next** launch. iCloud **account** status (`CKContainer.accountStatus`) is orthogonal and must not be framed as proof that journal data has finished syncing.

**iCloud sync toggle visibility:** `ICloudAccountBucket.showsICloudSyncToggle` is `false` for `.noAccount` and `.restricted` (same buckets as the **Open Settings** affordance). The Settings UI treats `displayedBucket == nil` as “show toggle” (`?? true`) so the row does not disappear during the initial account check.

**Non-goals (this slice):** Operational sync progress UI, restore-from-export in-app (see `0.6.0`), full CloudKit integration tests on Linux CI.

Related roadmap: [`GraceNotes/docs/07-release-roadmap.md`](../../../07-release-roadmap.md) § 0.4.0.
