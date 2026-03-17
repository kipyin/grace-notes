PROJECT := FiveCubedMoments/FiveCubedMoments.xcodeproj
SCHEME := FiveCubedMoments
DEMO_SCHEME := FiveCubedMoments (Demo)
DESTINATION := platform=iOS Simulator,name=iPhone 17,OS=latest

.PHONY: help lint build test test-demo test-all ci

help:
	@echo "Available targets:"
	@echo "  make lint   - Run SwiftLint checks"
	@echo "  make build  - Build app (macOS + Xcode required)"
	@echo "  make test   - Run tests for default scheme (macOS + Xcode + iOS Simulator required)"
	@echo "  make test-demo - Run tests for demo scheme (macOS + Xcode + iOS Simulator required)"
	@echo "  make test-all  - Run tests for both schemes"
	@echo "  make ci     - Run lint and test-all"

lint:
	swiftlint lint

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DESTINATION)' build

test:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DESTINATION)' test

test-demo:
	xcodebuild -project "$(PROJECT)" -scheme "$(DEMO_SCHEME)" -destination '$(DESTINATION)' test

test-all: test test-demo

ci: lint test-all
