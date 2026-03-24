# Initiative: AI features Settings status

## Section layout (Settings → AI)

- **Primary row:** Leading plain `Button` (“AI features” title + status subtitle when AI is on); trailing `Toggle` only changes `aiFeaturesEnabled` (instant, no network). No chevron or second expanded panel. VoiceOver: separate control for connection row vs AI toggle.
- **Inline subtitle (AI on):** Maps from `AISettingsCloudStatusModel.statusRow` when non-nil; when keyed and `statusRow == nil`, show “Tap for connection status.” Tapping the row (keyed) runs a reachability check.
- **Footer:** Stable education (“On: … Off: …”) only — no separate “Check connection” control.

## State → copy (EN source of truth in xcstrings)

| Internal / display intent | User mental model | Copy |
|---------------------------|-------------------|------|
| Toggle off | Off | No extra status row. |
| On, no key | On but cloud not available | “Cloud AI isn’t set up on this build.” |
| On, key, offline | Temporarily unreachable | “No internet connection” |
| Checking | Verifying | “Checking…” (inline text; no separate spinner row) |
| Check failed | Soft failure | “Couldn’t verify—try again” |
| Manual check succeeded | Confirmed reachability | “Connection looks good.” until cleared (see architecture) |
| On, key, online (nominal) | Prompt to verify | “Tap for connection status” |

## Precedence (single visible reason)

See `architecture.md` — misconfigured > checking > offline > checkFailed > manual success > nominal (`statusRow == nil` → tap hint when keyed).

## Accessibility

- Connection row: distinct label/hint from AI toggle; value reflects current subtitle (including “Off” when AI toggle off).
- Support **Dynamic Type**: multiline subtitle; do not rely on color alone.

## Voice

- Supportive, non-blaming; no “error,” “path,” or “route” in user-facing strings.
