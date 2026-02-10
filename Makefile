# MungMung Makefile

.PHONY: build build-debug test run clean release help

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
	@echo "Creating app bundle..."
	chmod +x Scripts/distribute.sh Scripts/create_dmg.sh
	Scripts/distribute.sh .build/release/MungMung $(VERSION)

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
	@echo "  make release VERSION=x.y.z - Build, sign, notarize, release"
	@echo ""
	@echo "Install:"
	@echo "  make install           - Install mung to /usr/local/bin"
	@echo "  make uninstall         - Remove mung from /usr/local/bin"
	@echo ""
	@echo "Utilities:"
	@echo "  make resolve           - Resolve dependencies"
	@echo "  make clean             - Clean all build artifacts"
	@echo "  make help              - Show this help"
