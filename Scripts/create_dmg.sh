#!/bin/bash
# create_dmg.sh - Create DMG installer for MungMung

set -e

APP_PATH="$1"
OUTPUT_DIR="${2:-./dist}"
VERSION_OVERRIDE="$3"

if [ -z "$APP_PATH" ]; then
    echo "Usage: create_dmg.sh /path/to/MungMung.app [output_dir] [version]"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

APP_NAME=$(basename "$APP_PATH" .app)
if [ -n "$VERSION_OVERRIDE" ]; then
    VERSION="$VERSION_OVERRIDE"
else
    VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.1.0")
fi
DMG_NAME="MungMung-${VERSION}"
DMG_PATH="$OUTPUT_DIR/${DMG_NAME}.dmg"
TEMP_DMG="/tmp/${DMG_NAME}-temp.dmg"
STAGING_DIR="/tmp/${DMG_NAME}-staging"

echo "=== Creating DMG for $APP_NAME $VERSION ==="

mkdir -p "$OUTPUT_DIR"

# Clean up leftover temp files
rm -f "$TEMP_DMG"
rm -rf "$STAGING_DIR"
hdiutil detach "/Volumes/MungMung" 2>/dev/null || true

# Create staging directory
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/MungMung.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Calculate size
APP_SIZE=$(du -sm "$STAGING_DIR" | cut -f1)
DMG_SIZE=$((APP_SIZE + 10))

# Create initial DMG
echo "=== Creating temporary DMG (${DMG_SIZE}MB) ==="
hdiutil create -srcfolder "$STAGING_DIR" \
    -volname "MungMung" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "$TEMP_DMG"

# Mount DMG
echo "=== Mounting for customization ==="
MOUNT_OUTPUT=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -E '/Volumes/' | awk '{print $3}')
echo "Mounted at: $MOUNT_POINT"

# Apply custom layout
echo "=== Applying custom layout ==="
osascript << 'APPLESCRIPT'
tell application "Finder"
    tell disk "MungMung"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100

        set position of item "MungMung.app" of container window to {125, 170}
        set position of item "Applications" of container window to {375, 170}

        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

# Finalize
echo "=== Finalizing DMG ==="
sync
sleep 2
hdiutil detach "$MOUNT_POINT" -force

# Convert to compressed read-only
echo "=== Converting to compressed DMG ==="
rm -f "$DMG_PATH"
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Cleanup
rm -rf "$STAGING_DIR" "$TEMP_DMG"

echo "=== DMG created: $DMG_PATH ==="
ls -lh "$DMG_PATH"
