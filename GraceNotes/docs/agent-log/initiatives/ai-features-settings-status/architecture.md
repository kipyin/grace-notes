# Initiative: AI features Settings status — architecture

## Decision

- **Configured key:** `ApiSecrets.isCloudApiKeyConfigured` (and `isUsableCloudApiKey(_:)` for injected keys in `ReviewInsightsProvider` tests).
- **Chip truncation:** `SummarizerProvider.effectiveUsesCloudForChips()` — `false` when `fixedSummarizer != nil`, else same predicate as `currentSummarizer()` for cloud vs deterministic.
- **Path:** `NWPathMonitor` on a dedicated queue; UI updates on `@MainActor` via `AISettingsCloudStatusModel`.
- **Probe:** `AICloudConnectivityVerifier` implementing `AICloudConnectivityVerifying` — `HEAD` to `CloudSummarizer` base origin + `/v1/models` fallback to `GET` if HEAD unsupported (implementation tries HEAD first). Success: HTTP 2xx–399 or 401/403 (host reachable). Failure: timeout, DNS, TLS, cancel, or 5xx.
- **Throttle:** Auto on-appear check only if no success in last **15 minutes** (`UserDefaults` stores last success `Date`). Manual check runs when the user taps the AI features row (keyed + AI on). **Do not** chain auto-probes off `NWPathMonitor` updates (avoids a second probe clearing manual failure/success before the user reads it).
- **Manual success:** After a successful **manual** probe, show **connectionVerified** (“Connection looks good.”) until cleared: starting a new manual check, AI toggled off, Settings disappear, or **local route becomes unsatisfied** (so returning online does not resurrect “looks good” without a new check). Automatic throttled probes do **not** set this state.
- **Presentation sync:** `refresh(aiFeaturesEnabled:)` drives monitor lifecycle. Settings shows a **single inline subtitle** under “AI features”: `statusRow` message when non-nil; when `statusRow == nil` and keyed, **“Tap for connection status.”**
- **Lifecycle:** Start path monitor when Settings appears **and** AI features are on; cancel on disappear. Refresh path when `scenePhase == .active`.

## Open questions

- Vendor may change HEAD behavior; adjust probe path if needed.

## Next owner

**QA Reviewer** — requirement fit; **Translator** — zh copy pass; **Test Lead** — `testing.md` matrix on device.
