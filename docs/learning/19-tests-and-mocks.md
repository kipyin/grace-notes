# 19 — Tests and mocks

## What you will learn

You will learn:
- where to find high-signal tests in this repo
- how mocks/spies are used here
- how to run focused tests first

This repo has unit tests and UI tests.

Use this page to learn where to look when a change feels risky.

## Test folders

- `../../GraceNotesTests/` — unit tests
- `../../GraceNotesUITests/` — UI tests

## Useful test doubles

Folder: `../../GraceNotesTests/TestDoubles/`

- `MockSummarizer.swift`
- `SpySummarizer.swift`
- `MockURLProtocol.swift`

These are used to:

- avoid real network calls
- count calls
- make behavior deterministic

Quick examples:
- `MockURLProtocol` intercepts `URLSession` for cloud tests.
- `SpySummarizer` counts calls for behavior assertions.

Real snippets:

```swift
final class MockSummarizer: Summarizer {
```

```swift
private(set) var summarizeCallCount = 0
```

```swift
static var mockResponse: ((URLRequest) -> (Data?, HTTPURLResponse?, Error?))?
```

How to read these snippets:
- first line defines deterministic summarizer fake
- second line tracks invocation count
- third line injects network response behavior for URLSession tests

## What is covered well

Examples:

- Journal view model behavior and limits
- review insight generators and policy
- import service validation and merge logic
- reminder scheduler + reminder settings model
- startup coordinator states

These suites are good reading material for how the team expects behavior to be specified.

Browse:

- `../../GraceNotesTests/Features/Journal/`
- `../../GraceNotesTests/Features/Settings/`
- `../../GraceNotesTests/Services/Reminders/`
- `../../GraceNotesTests/Services/Summarization/`
- `../../GraceNotesTests/Application/StartupCoordinatorTests.swift`

## UI tests

File to start with:

- `../../GraceNotesUITests/JournalUITests.swift`

These tests launch the app and drive real UI interactions.

They set specific launch flags to keep scenarios deterministic.

## Important caveats in current tests

You can see these in code comments and `XCTSkip` usage:

- some SwiftData tests skip on simulator due known crash conditions
- some timeline UI tests are intentionally skipped due simulator reliability issues

This is real project context, not test framework theory.

When reading tests, treat skip reasons as part of engineering reality, not “ignored noise.”

Real snippet:

```swift
throw XCTSkip("Skipping due to known hosted SwiftData malloc crash on current iOS simulator runtime.")
```

How to read this snippet:
- skip is intentional and documented
- this prevents false failures from known environment issue

## Running tests

Requires macOS + Xcode.

From repo root (`/workspace`) on macOS:

- `make test` (default scheme tests)
- `make test-unit`
- `make test-ui`

Make targets are defined in:

- `../../Makefile`

Linux note:
- you cannot run these iOS XCTest targets on Linux VM.
- you can still read test files and reason about behavior.

## How to use tests when making changes

1. Find the closest existing test file for your area.
2. Read how current behavior is asserted.
3. Add/update focused tests for your change.
4. Run only relevant targets first.
5. Broaden run scope after focused pass.

This keeps feedback fast and avoids noisy full-suite runs too early.

Example assertion style from repo:

```swift
XCTAssertEqual((entries[0].gratitudes ?? []).map(\.fullText), ["Family"])
```

## If you know Python

Think of this as:

- `pytest`-style unit tests for logic
- UI automation tests for integration/user flows

The test doubles are the same idea as mocks/stubs in Python testing.

## Read next

[20-swift-for-python-types-and-optionals.md](./20-swift-for-python-types-and-optionals.md)

## Quick check

1. Which test double helps intercept network requests?
2. Which snippet shows call-count tracking?
3. Why is `XCTSkip` sometimes the correct behavior?
