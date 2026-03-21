# Grace Notes learning path (for Python developers new to Swift)

This guide teaches the app through real code.

You will not just see “what file exists.”
You will see:
- short real snippet
- plain explanation
- why the app is built that way
- a small self-check

## Platform truth first

This app is iOS-only.

You need **macOS + Xcode 15+** to:
- build
- run in Simulator
- run XCTest/UI tests

On Linux, you can still learn a lot:
- read source code
- read tests
- run `swiftlint lint`

## How to study (simple method)

For each page:
1. Read the “What you will learn” section.
2. Read the snippet.
3. Read the snippet walkthrough line by line.
4. Do the quick check.
5. Move on only when you can explain the flow in your own words.

## Reading order

### Start here
1. [01-orientation.md](./01-orientation.md)

### Repo track (how this app works)
2. [10-architecture-big-picture.md](./10-architecture-big-picture.md)  
3. [11-app-startup-flow.md](./11-app-startup-flow.md)  
4. [12-data-and-swiftdata.md](./12-data-and-swiftdata.md)  
5. [13-journal-repository.md](./13-journal-repository.md)  
6. [14-journal-ui-and-viewmodel.md](./14-journal-ui-and-viewmodel.md)  
7. [15-summarization.md](./15-summarization.md)  
8. [16-settings-import-export.md](./16-settings-import-export.md)  
9. [17-reminders.md](./17-reminders.md)  
10. [18-onboarding.md](./18-onboarding.md)  
11. [19-tests-and-mocks.md](./19-tests-and-mocks.md)

### Swift track (learn Swift using this repo)
12. [20-swift-for-python-types-and-optionals.md](./20-swift-for-python-types-and-optionals.md)  
13. [21-swift-for-python-struct-class-protocol.md](./21-swift-for-python-struct-class-protocol.md)  
14. [22-swift-for-python-state-and-property-wrappers.md](./22-swift-for-python-state-and-property-wrappers.md)  
15. [23-swift-for-python-async-await.md](./23-swift-for-python-async-await.md)  
16. [24-swift-for-python-error-handling.md](./24-swift-for-python-error-handling.md)  
17. [25-swift-for-python-swiftdata-basics.md](./25-swift-for-python-swiftdata-basics.md)

### Tutorials (practice)
18. [30-tutorial-read-today-flow.md](./30-tutorial-read-today-flow.md)  
19. [31-tutorial-small-ui-copy-change.md](./31-tutorial-small-ui-copy-change.md)  
20. [32-tutorial-small-viewmodel-change-with-tests.md](./32-tutorial-small-viewmodel-change-with-tests.md)

## What you should be able to do after this

- Trace app startup from app entry to first screen.
- Explain where data is modeled, fetched, and saved.
- Explain how Today screen state flows into persistence.
- Explain why cloud/deterministic summarization switches.
- Add a small feature safely with focused tests.

## Quick rescue guide

- Lost? Start again at [01-orientation.md](./01-orientation.md).
- Save path unclear? Re-read page 14 (`JournalViewModel.persistChanges()`).
- AI behavior unclear? Re-read page 15 (`SummarizerProvider` + fallback path).

## Maintenance note

If code changes, update the matching learning page in the same PR.
