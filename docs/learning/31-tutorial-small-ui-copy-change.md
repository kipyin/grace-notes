# Tutorial 31 — Make a small UI copy change

## Goal

Change one onboarding message sentence and verify it in app UI.

This is a safe first “real change” workflow.

You will change one string only.

## What you need first

- macOS + Xcode 15+
- Project opens successfully: `GraceNotes/GraceNotes.xcodeproj`
- You can run the app on a simulator

If you are on Linux, you can still follow the edit steps, but you cannot run the iOS app there.

Time estimate:
- 15 to 30 minutes

---

## Real anchor snippet

```swift
} else if !hasCompletedOnboarding {
    OnboardingScreen {
        hasCompletedOnboarding = true
    }
}
```

Why this snippet matters:
- it proves onboarding appears only when the stored flag is false
- if you cannot see onboarding, this logic explains why

## Steps (with why)

1. Open `../../GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift`.  
   Why: this file owns onboarding page text.

2. In `pages`, pick one `message:` value only.  
   Why: one change keeps test surface small.

3. Edit the sentence. Keep it short and clear.  
   Why: long copy can clip or wrap poorly.

4. Build and run in Xcode.  
   Why: confirms no syntax/localization issues.

5. If onboarding is skipped, clear app data in simulator and rerun.  
   Why: `hasCompletedOnboarding` might already be true.

6. Swipe onboarding pages and verify new text appears once in correct page.  
   Why: catches accidental edits to wrong string.

7. Check at least one small + one large device size.  
   Why: catches layout wrapping issues.

## Real snippets to anchor this change

In onboarding page data:

```swift
private let pages: [OnboardingPage] = [
```

One message entry:

```swift
message: String(
    localized: "Capture one gratitude and move on with your day. A meaningful check-in can take under two minutes."
)
```

Where onboarding is gated in app root:

```swift
} else if !hasCompletedOnboarding {
    OnboardingScreen {
        hasCompletedOnboarding = true
    }
}
```

## Verification checklist

Success means:

- app builds
- onboarding screen shows
- edited sentence appears exactly once where expected
- layout still looks clean (no clipping/truncation)

Optional evidence:
- keep one screenshot of updated page for review notes

## What usually breaks (and fixes)

- Editing the wrong string (title vs message).
- Simulator still has `hasCompletedOnboarding = true`, so onboarding is skipped.
- Copy becomes too long and wraps poorly on smaller devices.

If onboarding still does not show:
- uninstall app from simulator
- rerun app from Xcode

## Optional harder step

Make the same copy update in localization resources and verify both languages in simulator.

Start from:

- `../../GraceNotes/GraceNotes/Localizable.xcstrings`

Keep meaning identical across languages.

Also check that the edited key is still used by `OnboardingScreen`.
