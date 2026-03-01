# MungMung Makefile

.PHONY: build build-debug test verify-release run clean release icon help

.DEFAULT_GOAL := help

# =============================================================================
# Build
# =============================================================================

## Build release binary
build:
	@echo "Building release..."
	swift build -c release

## Build debug binary
build-debug:
	@echo "Building debug..."
	swift build

## Run the built application (debug)
run: build-debug
	@echo "Running MungMung..."
	.build/debug/MungMung $(ARGS)

## Run tests
test:
	@echo "Running tests..."
	swift build && swift test

## Run release-hardening verification checks
verify-release:
	@echo "Running release-hardening verification..."
	swift build -c release
	swift test
	.build/release/MungMung doctor --json >/dev/null

## Build release app, create DMG, and upload to GitHub Release
## Usage: make release VERSION=0.1.0
release:
ifndef VERSION
	@echo "Error: VERSION is required"
	@echo "Usage: make release VERSION=0.1.0"
	@exit 1
endif
	@echo "Building release v$(VERSION)..."
	swift build -c release
	@echo "Creating distribution..."
	chmod +x Scripts/distribute.sh Scripts/create_dmg.sh Scripts/create_app_bundle.sh
	Scripts/distribute.sh .build/release/MungMung $(VERSION)
	@echo ""
	@echo "Release artifacts created in dist/"
	@ls -la dist/

# =============================================================================
# Install
# =============================================================================

## Install mung CLI to /usr/local/bin
install: build
	@echo "Installing mung to /usr/local/bin..."
	cp .build/release/MungMung /usr/local/bin/mung
	@echo "Installed. Run: mung help"

## Uninstall mung CLI
uninstall:
	rm -f /usr/local/bin/mung
	@echo "Uninstalled mung."

# =============================================================================
# Utilities
# =============================================================================

## Regenerate app icon with squircle mask from source artwork
icon:
	@echo "Generating app icon..."
	swift Scripts/generate_icon.swift
	@echo "Icon generated. Verify with: open Resources/AppIcon.icns"

## Resolve package dependencies
resolve:
	@echo "Resolving dependencies..."
	swift package resolve

## Clean build artifacts
clean:
	@echo "Cleaning..."
	swift package clean
	rm -rf .build
	rm -rf dist

## Show help
help:
	@echo "MungMung Makefile"
	@echo ""
	@echo "Building:"
	@echo "  make build             - Build release binary"
	@echo "  make build-debug       - Build debug binary"
	@echo "  make run ARGS='help'   - Build and run with arguments"
	@echo "  make test              - Run unit tests"
	@echo "  make verify-release    - Run release-hardening verification checks"
	@echo "  make release VERSION=x.y.z - Build, sign, notarize, release"
	@echo ""
	@echo "Install:"
	@echo "  make install           - Install mung to /usr/local/bin"
	@echo "  make uninstall         - Remove mung from /usr/local/bin"
	@echo ""
	@echo "Utilities:"
	@echo "  make icon              - Regenerate app icon with squircle mask"
	@echo "  make resolve           - Resolve dependencies"
	@echo "  make clean             - Clean all build artifacts"
	@echo "  make help              - Show this help"
