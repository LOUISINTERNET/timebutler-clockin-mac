MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := help

# Colors (use $(shell printf) — Make does not interpret \033 directly)
COLOR_GREEN=$(shell printf '\033[0;32m')
COLOR_RED=$(shell printf '\033[0;31m')
COLOR_BLUE=$(shell printf '\033[0;34m')
COLOR_CYAN=$(shell printf '\033[36m')
COLOR_OFF=$(shell printf '\033[0m')

# Xcode 26 hangs at "Discovering version info for clang" because the verbose probe output
# exceeds the 16 KB pipe buffer SWBBuildService reads from. Stripping -v keeps it under.
export CCC_OVERRIDE_OPTIONS := x-v

PROJECT := ClockIn.xcodeproj
SCHEME := ClockIn
DERIVED_DATA := build
APP := $(DERIVED_DATA)/Build/Products/Debug/ClockIn.app
ARCH := $(shell uname -m)
# Extra build settings. The release workflow signs ad hoc, because Debug signs automatically and
# the runner has no development certificate: make test XCODEBUILD_FLAGS="CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-"
XCODEBUILD_FLAGS ?=
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) -destination 'platform=macOS,arch=$(ARCH)' -quiet $(XCODEBUILD_FLAGS)

define ASCII_ART
	@echo "   ________           __      ____    "
	@echo "  / ____/ /___  _____/ /__   /  _/___ "
	@echo " / /   / / __ \/ ___/ //_/   / // __ \\"
	@echo "/ /___/ / /_/ / /__/ ,<    _/ // / / /"
	@echo "\____/_/\____/\___/_/|_|  /___/_/ /_/"
	@echo ""
endef

define display_help
	@echo "$(1)"
	@grep -E '^[a-zA-Z0-9_-]+:\s?##$(2)\s.*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?##$(2) "}; {gsub("\\\\n", "\n\t", $$2); printf "$(COLOR_CYAN)%-30s$(COLOR_OFF) %s\n", $$1, $$2}'
	@echo
endef

# Documentation part -----------------------------------------------------

help: ##1 Show this help
	@$(ASCII_ART)
	$(call display_help,"Documentation:",1)
	$(call display_help,"Development:",4)

# Development ------------------------------------------------------------

generate: ##4 Generate the Xcode project from project.yml
	xcodegen generate

build: ##4 Build the Debug app into build/
	$(MAKE) generate
	$(XCODEBUILD) -configuration Debug build
	echo "$(COLOR_GREEN)Built $(APP)$(COLOR_OFF)"

run: ##4 Build and launch the Debug app
	$(MAKE) build
	open "$(APP)"

test: ##4 Run the unit tests (offline, fixtures only)
	$(MAKE) generate
	$(XCODEBUILD) -configuration Debug test -skip-testing:ClockInTests/LiveAPITests
	xcrun xcresulttool get test-results summary --path "$$(ls -td $(DERIVED_DATA)/Logs/Test/*.xcresult | head -1)" | python3 -c 'import json, sys; summary = json.load(sys.stdin); print(summary["passedTests"], "tests passed,", summary["failedTests"], "failed"); sys.exit(0 if summary["passedTests"] > 0 and summary["failedTests"] == 0 else 1)' || { echo "$(COLOR_RED)No tests ran or some failed$(COLOR_OFF)"; exit 1; }
	echo "$(COLOR_GREEN)Tests passed$(COLOR_OFF)"

test-live: ##4 Call the real Timebutler API with TIMEBUTLER_API_TOKEN from the environment
	test -n "$(TIMEBUTLER_API_TOKEN)" || { echo "$(COLOR_RED)TIMEBUTLER_API_TOKEN is not set. Run: read -s TIMEBUTLER_API_TOKEN && export TIMEBUTLER_API_TOKEN && make test-live$(COLOR_OFF)"; exit 1; }
	$(MAKE) generate
	TEST_RUNNER_TIMEBUTLER_API_TOKEN="$$TIMEBUTLER_API_TOKEN" $(XCODEBUILD) -configuration Debug test -only-testing:ClockInTests/LiveAPITests
	xcrun xcresulttool get test-results summary --path "$$(ls -td $(DERIVED_DATA)/Logs/Test/*.xcresult | head -1)" | python3 -c 'import json, sys; summary = json.load(sys.stdin); sys.exit(0 if summary["passedTests"] == 1 and summary["skippedTests"] == 0 else 1)' || { echo "$(COLOR_RED)Live API test did not run: the token did not reach the test process$(COLOR_OFF)"; exit 1; }
	echo "$(COLOR_GREEN)Live API test passed: profile, status and work summary decoded$(COLOR_OFF)"

install: ##4 Copy the Debug app to /Applications
	$(MAKE) build
	rm -rf "/Applications/ClockIn.app"
	ditto "$(APP)" "/Applications/ClockIn.app"
	echo "$(COLOR_GREEN)Installed /Applications/ClockIn.app$(COLOR_OFF)"

clean: ##4 Remove build output and the generated Xcode project
	rm -rf "$(DERIVED_DATA)" dist "$(PROJECT)"

.PHONY: help generate build run test test-live install clean
.SILENT:
