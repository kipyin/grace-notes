# QA matrix: AI Settings cloud status

| Case | Steps | Expected |
|------|--------|----------|
| First tap | Open Settings, toggle AI on | Toggle flips immediately; no hang |
| Misconfigured | AI on, placeholder key | Subtitle: “Cloud AI isn’t set up…” |
| Offline | AI on, real key, airplane mode | Subtitle “No internet connection”; toggle stays on |
| Nominal | AI on, key, online, no failed probe, no sticky success | Subtitle “Tap for connection status” |
| Row tap check | Tap row (keyed + online) | “Checking…” then “Connection looks good.” until cleared (see architecture); no auto-dismiss timer |
| After offline | Success, then lose route | “No internet connection”; sticky success cleared |
| Settings leave | After success, leave Settings and return | Sticky success cleared; nominal shows tap hint until next check |
| Auto check | Open Settings with stale success throttle | Throttled auto-probe may run silently; does **not** show “Connection looks good.” alone |
| Check failure | Tap row with blocked API / 5xx (if simulable) | “Couldn’t verify—try again” |
| Dynamic Type | Largest sizes | Status multiline, no clipping |
| VoiceOver | Focus AI section | Distinct focus for connection row vs AI toggle |
| Precedence | Misconfigured + offline | Misconfigured copy only |

## Unit tests (GraceNotesTests)

- `AISettingsCloudStatusModelTests` — mock `AICloudConnectivityVerifying`, `installsPathMonitor: false`, injected `cloudApiKeyConfigured`; covers manual success showing `connectionVerified`, auto probe not showing `connectionVerified`, `onSettingsDisappear` clearing sticky, misconfigured when key missing.

**Execution evidence:** From repo root on macOS + Xcode, pick an available Simulator in `xcodebuild -showdestinations -scheme GraceNotes`, then run:

`xcodebuild -project GraceNotes/GraceNotes.xcodeproj -scheme GraceNotes -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:GraceNotesTests/AISettingsCloudStatusModelTests test`

(Automated run: GraceNotesTests target compiled; Simulator app install failed in the agent environment—re-run locally to confirm green.)
