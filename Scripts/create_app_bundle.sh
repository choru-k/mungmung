#!/bin/bash
# create_app_bundle.sh - Create MungMung.app bundle from SPM release build
#
# SPM builds a plain binary. For macOS distribution we need a proper .app bundle
# with Info.plist, entitlements, and the binary inside Contents/MacOS/.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

BINARY="${1:-.build/release/MungMung}"
OUTPUT_DIR="${2:-$PROJECT_DIR/dist}"
APP_NAME="MungMung"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    echo "Run 'swift build -c release' first."
    exit 1
fi

echo "=== Creating $APP_NAME.app bundle ==="

# Clean and create structure
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy app icon
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Copy menu bar icons
cp "$PROJECT_DIR/Resources/MenuBarIcon.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon.png"
cp "$PROJECT_DIR/Resources/MenuBarIcon@2x.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon@2x.png"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Create symlink for CLI: mung -> MungMung
# Users can symlink /usr/local/bin/mung -> MungMung.app/Contents/MacOS/MungMung
# Or Homebrew handles this via the binary stanza in the cask formula

echo "=== App bundle created: $APP_BUNDLE ==="
ls -la "$APP_BUNDLE/Contents/MacOS/"
