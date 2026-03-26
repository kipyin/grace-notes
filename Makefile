PROJECT := GraceNotes/GraceNotes.xcodeproj
SCHEME := GraceNotes
DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
# Default pins for CI. Override if runtimes differ; see `make list-simulator-destinations`.
CI_SIMULATOR_PRO ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2
CI_SIMULATOR_XR ?= platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.5
TEST_DESTINATION_MATRIX ?= iPhone SE (3rd generation)@18.5;iPhone 17 Pro@26.2
ISOLATED_DERIVED_DATA := /tmp/GraceNotes-TestDerivedData
UNIT_TEST_BUNDLE := GraceNotesTests
UI_TEST_BUNDLE := GraceNotesUITests
SMOKE_UI_TEST := GraceNotesUITests/GraceNotesSmokeUITests/testSmokeLaunch
XCODE_TEST_FLAGS := -parallel-testing-enabled NO
PYTHON ?= python3
SIMULATOR_HELPER := Scripts/simulator_destination.py
# iOS 17 hosted runtime can crash in these suites before assertions run.
LEGACY_RUNTIME_SKIP_FLAGS := -skip-testing:GraceNotesTests/CloudReviewInsightsGeneratorTests -skip-testing:GraceNotesTests/DeterministicReviewInsightsTests -skip-testing:GraceNotesTests/HistoryEntryGroupingTests

.PHONY: help lint lint-preflight build test test-unit test-ui test-ui-smoke test-isolated test-all test-matrix ci ci-matrix ci-build ci-full ci-merge-queue ci-pr-full-ci reset-simulators list-simulator-destinations validate-destination validate-test-matrix

help:
	@echo "Available targets:"
	@echo "  make lint   - Run SwiftLint checks"
	@echo "  make build  - Build app (macOS + Xcode required)"
	@echo "  make test   - Run tests for GraceNotes scheme on DESTINATION"
	@echo "  make test-unit - Run unit tests only"
	@echo "  make test-ui   - Run UI tests only"
	@echo "  make test-isolated - Run tests with isolated DerivedData to avoid Xcode contention"
	@echo "  make test-all  - Reset simulators, then run tests (GraceNotes scheme only)"
	@echo "  make test-matrix - Run GraceNotes tests across TEST_DESTINATION_MATRIX"
	@echo "  make validate-destination - Resolve DESTINATION to an installed runtime"
	@echo "  make validate-test-matrix - Validate matrix destinations"
	@echo "  make list-simulator-destinations - List installed iOS simulator destinations"
	@echo "  make reset-simulators - Shutdown and erase all simulators"
	@echo "  make ci     - Run lint and test-all"
	@echo "  make ci-matrix - Run lint and test-matrix"
	@echo "  make ci-build - Build for CI_SIMULATOR_PRO (used by GitHub Actions)"
	@echo "  make ci-full - Lint, test on CI_SIMULATOR_PRO, UI smoke on CI_SIMULATOR_XR (GitHub Actions full suite)"
	@echo "  make ci-merge-queue - Alias for ci-full (compat)"
	@echo "  make ci-pr-full-ci - Alias for ci-full (PR label full-ci in Actions)"
	@echo ""
	@echo "Configurable variables:"
	@echo "  DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'"
	@echo "  TEST_DESTINATION_MATRIX='iPhone SE (3rd generation)@18.5;iPhone 17 Pro@26.2'"
	@echo ""
	@echo "Note: GraceNotes (Demo) scheme remains in Xcode for sample-data runs; Makefile does not test it."

list-simulator-destinations:
	@$(PYTHON) "$(SIMULATOR_HELPER)" list

validate-destination:
	@resolved_destination="$$($(PYTHON) "$(SIMULATOR_HELPER)" resolve "$(DESTINATION)")" || exit $$?; \
	echo "Resolved destination: $$resolved_destination"

validate-test-matrix:
	@$(PYTHON) "$(SIMULATOR_HELPER)" matrix-destinations "$(TEST_DESTINATION_MATRIX)" >/dev/null && \
	echo "Matrix destinations are valid."

lint:
	@$(MAKE) lint-preflight
	swiftlint lint

lint-preflight:
	@if ! command -v swiftlint >/dev/null 2>&1; then \
		echo "SwiftLint is not installed or not on PATH."; \
		echo "Install with Homebrew: brew install swiftlint"; \
		exit 1; \
	fi

build:
	@resolved_destination="$$($(PYTHON) "$(SIMULATOR_HELPER)" resolve "$(DESTINATION)")" || exit $$?; \
	echo "Using destination: $$resolved_destination"; \
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$$resolved_destination" build

test:
	@resolved_destination="$$($(PYTHON) "$(SIMULATOR_HELPER)" resolve "$(DESTINATION)")" || exit $$?; \
	runtime_version="$${resolved_destination##*OS=}"; \
	extra_flags=""; \
	if [ "$${runtime_version%%.*}" -lt 18 ]; then \
		extra_flags="$(LEGACY_RUNTIME_SKIP_FLAGS)"; \
		echo "Applying legacy runtime skip flags: $$extra_flags"; \
	fi; \
	echo "Using destination: $$resolved_destination"; \
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$$resolved_destination" $(XCODE_TEST_FLAGS) $$extra_flags test

test-unit:
	@resolved_destination="$$($(PYTHON) "$(SIMULATOR_HELPER)" resolve "$(DESTINATION)")" || exit $$?; \
	runtime_version="$${resolved_destination##*OS=}"; \
	extra_flags=""; \
	if [ "$${runtime_version%%.*}" -lt 18 ]; then \
		extra_flags="$(LEGACY_RUNTIME_SKIP_FLAGS)"; \
		echo "Applying legacy runtime skip flags: $$extra_flags"; \
	fi; \
	echo "Using destination: $$resolved_destination"; \
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$$resolved_destination" $(XCODE_TEST_FLAGS) $$extra_flags -only-testing:"$(UNIT_TEST_BUNDLE)" test

test-ui:
	@resolved_destination="$$($(PYTHON) "$(SIMULATOR_HELPER)" resolve "$(DESTINATION)")" || exit $$?; \
	echo "Using destination: $$resolved_destination"; \
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$$resolved_destination" $(XCODE_TEST_FLAGS) -only-testing:"$(UI_TEST_BUNDLE)" test

test-ui-smoke:
	@resolved_destination="$$($(PYTHON) "$(SIMULATOR_HELPER)" resolve "$(DESTINATION)")" || exit $$?; \
	simulator_name="$$($(PYTHON) "$(SIMULATOR_HELPER)" name "$$resolved_destination")" || exit $$?; \
	echo "Using destination: $$resolved_destination"; \
	$(MAKE) reset-simulators; \
	xcrun simctl boot "$$simulator_name" >/dev/null 2>&1 || true; \
	xcrun simctl bootstatus "$$simulator_name" -b >/dev/null 2>&1 || true; \
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$$resolved_destination" $(XCODE_TEST_FLAGS) -only-testing:"$(SMOKE_UI_TEST)" test

test-isolated:
	@resolved_destination="$$($(PYTHON) "$(SIMULATOR_HELPER)" resolve "$(DESTINATION)")" || exit $$?; \
	runtime_version="$${resolved_destination##*OS=}"; \
	extra_flags=""; \
	if [ "$${runtime_version%%.*}" -lt 18 ]; then \
		extra_flags="$(LEGACY_RUNTIME_SKIP_FLAGS)"; \
		echo "Applying legacy runtime skip flags: $$extra_flags"; \
	fi; \
	echo "Using destination: $$resolved_destination"; \
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$$resolved_destination" $(XCODE_TEST_FLAGS) $$extra_flags -derivedDataPath "$(ISOLATED_DERIVED_DATA)" test

reset-simulators:
	xcrun simctl shutdown all || true
	xcrun simctl erase all || true

test-all:
	$(MAKE) reset-simulators
	$(MAKE) test

test-matrix:
	@set -eu; \
	tmp_file="$$(mktemp)"; \
	trap 'rm -f "$$tmp_file"' EXIT; \
	$(PYTHON) "$(SIMULATOR_HELPER)" matrix-destinations "$(TEST_DESTINATION_MATRIX)" > "$$tmp_file"; \
	while IFS= read -r matrix_destination; do \
		[ -z "$$matrix_destination" ] && continue; \
		runtime_version="$${matrix_destination##*OS=}"; \
		extra_flags=""; \
		if [ "$${runtime_version%%.*}" -lt 18 ]; then \
			extra_flags="$(LEGACY_RUNTIME_SKIP_FLAGS)"; \
			echo "Applying legacy runtime skip flags: $$extra_flags"; \
		fi; \
		echo "==> Running $(SCHEME) on $$matrix_destination"; \
		$(MAKE) reset-simulators; \
		xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$$matrix_destination" $(XCODE_TEST_FLAGS) $$extra_flags test; \
	done < "$$tmp_file"

ci:
	$(MAKE) lint
	$(MAKE) test-all

ci-matrix:
	$(MAKE) lint
	$(MAKE) test-matrix

ci-build:
	$(MAKE) build DESTINATION="$(CI_SIMULATOR_PRO)"

ci-full:
	$(MAKE) lint
	$(MAKE) test DESTINATION="$(CI_SIMULATOR_PRO)"
	$(MAKE) test-ui-smoke DESTINATION="$(CI_SIMULATOR_XR)"

ci-merge-queue: ci-full

ci-pr-full-ci: ci-full
