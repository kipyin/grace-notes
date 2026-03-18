# TestFlight Readiness Checklist

This document captures what needs to be done to ship the first TestFlight build of Grace Notes.

---

## Done (Code / Project)

| Item | Status |
|------|--------|
| App Icon filename | Fixed: `Contents.json` now references `five-cubed-moments-icon-1024x1024-2.png` (was pointing to non-existent `grace-notes-icon-1024x1024.png`) |
| Privacy manifest | Added `PrivacyInfo.xcprivacy` with UserDefaults declaration (CA92.1) — required for App Store since May 2024 |
| Bundle ID | `com.gracenotes.GraceNotes` |
| Display name | "Grace Notes" |
| Category | Lifestyle |
| Deployment target | iOS 17.0 |
| Signing | Automatic, DEVELOPMENT_TEAM = C2ST94AYSS |
| Entitlements | iCloud, CloudKit, push (aps-environment) |
| Info.plist | NSPhotoLibraryAddUsageDescription, UIBackgroundModes (remote-notification), UIAppFonts |

---

## You Must Do (macOS + Xcode)

### 1. Verify / fix development team

- Open the project in Xcode and confirm **Signing & Capabilities** uses your Apple Developer team.
- If `C2ST94AYSS` is not your team, change it in the project settings.

### 2. Archive and upload

1. Select the **GraceNotes** scheme (not Demo).
2. Choose **Any iOS Device (arm64)** or a connected device as the destination.
3. **Product → Archive**.
4. When the Organizer opens: **Distribute App** → **App Store Connect** → **Upload**.
5. Follow the prompts (automatic signing, default options).

### 3. Optional: Bump version before first TestFlight

- Current: `MARKETING_VERSION = 0.3.2`, `CURRENT_PROJECT_VERSION = 1`
- Branch context: `release/0.3.3` / `cursor/app-store-publishing-limitations-dddf`
- For first TestFlight you can keep 0.3.2 build 1, or align with roadmap (e.g. 0.3.3 build 1).

---

## You Must Do (App Store Connect)

### 4. Create the app record (if new)

1. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**.
2. Platform: iOS.
3. Name: **Grace Notes**.
4. Primary language: English.
5. Bundle ID: select `com.gracenotes.GraceNotes`.
6. SKU: any unique string (e.g. `gracenotes-001`).

### 5. Wait for build processing

- After upload, the build usually processes in 15–30 minutes.
- You’ll get an email when it’s ready.

### 6. Configure TestFlight

1. Open the app → **TestFlight**.
2. Select the build.
3. **Export compliance**: typically **No** (app uses only standard encryption).
4. **Advertising identifier (IDFA)**: **No** (Grace Notes does not use IDFA).
5. Add **Beta App Description** (what testers should focus on).
6. Add **Test Information** if using external testers (contact info, what to test).

### 7. Add internal testers

- **Internal testing**: add people from your App Store Connect team (up to 100).
- No Beta App Review; they get the build shortly after processing.

### 8. External testers (optional)

- Add external testers or groups.
- Submit for **Beta App Review**.
- Provide Test Information (description, contact email).

---

## Pre-submit Checks

| Check | Notes |
|-------|-------|
| Build destination | Use "Any iOS Device" or a real device for Archive; Simulator builds cannot be uploaded |
| Scheme | Use **GraceNotes**, not GraceNotes (Demo) |
| Cloud summarization | Uses placeholder `YOUR_KEY_HERE` → falls back to on-device summarization |

---

## If PrivacyInfo.xcprivacy Is Not in the Bundle

If the build succeeds but App Store Connect flags a missing privacy manifest:

1. In Xcode, right-click the **GraceNotes** group.
2. **Add Files to "GraceNotes"**.
3. Select `GraceNotes/PrivacyInfo.xcprivacy`.
4. Ensure the **GraceNotes** target is checked.
5. Re-archive and upload.

---

## SwiftLint

- Four style warnings (line length, file length) — non-blocking for TestFlight.
- Run `swiftlint lint` or `make lint` before release if you want to clean these up.

---

## Summary

**Code changes applied:**

- Fixed App Icon reference in `AppIcon.appiconset/Contents.json`.
- Added `PrivacyInfo.xcprivacy` with UserDefaults API declaration.

**Your responsibilities:**

- Archive and upload on macOS with Xcode.
- Create/configure the app in App Store Connect.
- Answer export compliance and IDFA in TestFlight.
- Add testers and start testing.
