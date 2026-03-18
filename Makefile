PROJECT := GraceNotes/GraceNotes.xcodeproj
SCHEME := GraceNotes
DEMO_SCHEME := GraceNotes (Demo)
DESTINATION := platform=iOS Simulator,name=iPhone 17,OS=latest
ISOLATED_DERIVED_DATA := /tmp/GraceNotes-TestDerivedData
UNIT_TEST_BUNDLE := GraceNotesTests
UI_TEST_BUNDLE := GraceNotesUITests
XCODE_TEST_FLAGS := -parallel-testing-enabled NO

.PHONY: help lint build test test-unit test-ui test-isolated test-demo test-all ci reset-simulators verify-agent-log verify-agent-log-strict

help:
	@echo "Available targets:"
	@echo "  make lint   - Run SwiftLint checks"
	@echo "  make build  - Build app (macOS + Xcode required)"
	@echo "  make test   - Run tests for default scheme (macOS + Xcode + iOS Simulator required)"
	@echo "  make test-unit - Run unit tests only for default scheme"
	@echo "  make test-ui   - Run UI tests only for default scheme"
	@echo "  make test-isolated - Run tests with isolated DerivedData to avoid Xcode contention"
	@echo "  make test-demo - Run tests for demo scheme (macOS + Xcode + iOS Simulator required)"
	@echo "  make test-all  - Run tests for both schemes"
	@echo "  make reset-simulators - Shutdown and erase all simulators"
	@echo "  make verify-agent-log - Run warning-mode agent-log validation"
	@echo "  make verify-agent-log-strict - Run strict agent-log validation"
	@echo "  make ci     - Run lint and full-suite tests with simulator resets"

lint:
	swiftlint lint

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DESTINATION)' build

test:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DESTINATION)' $(XCODE_TEST_FLAGS) test

test-unit:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DESTINATION)' $(XCODE_TEST_FLAGS) -only-testing:"$(UNIT_TEST_BUNDLE)" test

test-ui:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DESTINATION)' $(XCODE_TEST_FLAGS) -only-testing:"$(UI_TEST_BUNDLE)" test

test-isolated:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DESTINATION)' $(XCODE_TEST_FLAGS) -derivedDataPath "$(ISOLATED_DERIVED_DATA)" test

test-demo:
	xcodebuild -project "$(PROJECT)" -scheme "$(DEMO_SCHEME)" -destination '$(DESTINATION)' $(XCODE_TEST_FLAGS) test

reset-simulators:
	xcrun simctl shutdown all || true
	xcrun simctl erase all || true

test-all:
	$(MAKE) test
	$(MAKE) test-demo

verify-agent-log:
	./Scripts/validate-agent-log.sh

verify-agent-log-strict:
	./Scripts/validate-agent-log.sh --strict

ci:
	$(MAKE) lint
	$(MAKE) reset-simulators
	$(MAKE) test
	$(MAKE) reset-simulators
	$(MAKE) test-demo
