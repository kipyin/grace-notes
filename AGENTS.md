# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

**Five Cubed Moments** is a native iOS journaling app (SwiftUI + SwiftData). It is a single Xcode project with zero third-party dependencies. See `README.md` for features and project structure.

### Platform constraint

This project **requires macOS + Xcode 15+** to build, run, and test. The Cloud Agent Linux VM cannot compile Swift code that depends on iOS SDK frameworks (SwiftUI, SwiftData, UIKit). There is no backend, no API server, and no web UI—everything runs on-device in the iOS Simulator.

### What works on Linux

- **Linting**: `swiftlint lint` (SwiftLint static binary is installed at `/usr/local/bin/swiftlint`). Runs without the Swift toolchain; reports style violations across all 17 Swift source files. The dynamic SwiftLint binary will crash on Linux because `libsourcekitdInProc.so` is unavailable; always use the `-static` variant.
- **Code review / static analysis**: Reading and reviewing Swift source files.

### What does NOT work on Linux

- `xcodebuild build` / `xcodebuild test` — requires macOS + Xcode + iOS Simulator.
- Running the app in the iOS Simulator — requires macOS.
- Unit tests (`FiveCubedMomentsTests`) and UI tests (`FiveCubedMomentsUITests`) — require Xcode test runner.

### Build and test commands (macOS only)

```bash
xcodebuild \
  -project FiveCubedMoments/FiveCubedMoments.xcodeproj \
  -scheme FiveCubedMoments \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  test
```

See `.github/workflows/ios-ci.yml` for CI configuration.

### Lint command

```bash
swiftlint lint
```

Runs from the repo root; lints all `.swift` files recursively. Currently reports 12 warnings (no errors).
