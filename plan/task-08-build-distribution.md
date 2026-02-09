# Task 8: Build & Distribution Pipeline

## Background

mungmung is distributed as a macOS `.app` bundle via Homebrew cask. The distribution pipeline follows the same pattern as PasteFence:

1. Build release binary via `swift build -c release`
2. Create `.app` bundle from the built binary + Info.plist + entitlements
3. Code sign with Developer ID
4. Create DMG installer
5. Sign the DMG
6. Notarize with Apple
7. Staple notarization ticket
8. Generate SHA256 checksum
9. Create GitHub release + upload assets
10. Update Homebrew tap

**Reference:** PasteFence's `Scripts/distribute.sh`, `Scripts/create_dmg.sh`, and `Casks/pastefence.rb` at `~/Desktop/choru/pastefence/`.

**Key difference from PasteFence:** MungMung is a pure SPM build (no Xcode project), so we create the `.app` bundle manually from the built binary, Info.plist, and entitlements. PasteFence uses `xcodebuild` because it has an Xcode project.

## Dependencies

- **Tasks 1-7** — all code must be complete and building

## Files to Create

| File | Purpose |
|------|---------|
| `Scripts/distribute.sh` | Complete distribution pipeline (sign, notarize, release) |
| `Scripts/create_dmg.sh` | DMG creation with custom layout |
| `Scripts/create_app_bundle.sh` | Create .app bundle from SPM build output |
| `Casks/mungmung.rb` | Homebrew cask formula |

## Implementation

### `Scripts/create_app_bundle.sh`

Since MungMung uses SPM (no Xcode project), we need to manually create the `.app` bundle from the release binary.

```bash
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

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Create symlink for CLI: mung -> MungMung
# Users can symlink /usr/local/bin/mung -> MungMung.app/Contents/MacOS/MungMung
# Or Homebrew handles this via the binary stanza in the cask formula

echo "=== App bundle created: $APP_BUNDLE ==="
ls -la "$APP_BUNDLE/Contents/MacOS/"
```

### `Scripts/distribute.sh`

```bash
#!/bin/bash
# distribute.sh - Build, sign, notarize, and distribute MungMung
#
# Usage: ./Scripts/distribute.sh [binary_path] VERSION
#
# If binary_path is omitted, uses .build/release/MungMung
# Creates .app bundle, signs, creates DMG, notarizes, uploads to GitHub.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"

# Code signing configuration
DEVELOPER_ID="Developer ID Application: Cheol Kang (ESURPGU29C)"
KEYCHAIN_PROFILE="MungMungNotarization"
ENTITLEMENTS="$PROJECT_DIR/MungMung.entitlements"

echo "=== MungMung Distribution Script ==="
echo "Project: $PROJECT_DIR"

# Parse arguments
if [ "$#" -eq 1 ]; then
    BINARY_PATH=".build/release/MungMung"
    VERSION="$1"
elif [ "$#" -eq 2 ]; then
    BINARY_PATH="$1"
    VERSION="$2"
else
    echo "Usage: $0 [binary_path] VERSION"
    echo "Example: $0 0.1.0"
    echo "Example: $0 .build/release/MungMung 0.1.0"
    exit 1
fi

echo "Version: $VERSION"

# Clean dist directory
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Step 1: Create app bundle
echo ""
echo "=== Step 1: Creating App Bundle ==="
"$SCRIPT_DIR/create_app_bundle.sh" "$BINARY_PATH" "$DIST_DIR"
APP_PATH="$DIST_DIR/MungMung.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle creation failed"
    exit 1
fi

# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"

# Step 2: Sign app bundle
echo ""
echo "=== Step 2: Signing App Bundle ==="
echo "Signing with: $DEVELOPER_ID"

codesign --force --options runtime \
    --sign "$DEVELOPER_ID" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"

echo "App signed successfully"
codesign --verify --verbose "$APP_PATH"

# Step 3: Create DMG
echo ""
echo "=== Step 3: Creating DMG ==="
"$SCRIPT_DIR/create_dmg.sh" "$APP_PATH" "$DIST_DIR" "$VERSION"

# Get DMG file
DMG_FILE=$(ls "$DIST_DIR"/*.dmg 2>/dev/null | head -1)

if [ -z "$DMG_FILE" ]; then
    echo "Error: No DMG file found"
    exit 1
fi

# Step 4: Sign DMG
echo ""
echo "=== Step 4: Signing DMG ==="
codesign --force --sign "$DEVELOPER_ID" "$DMG_FILE"
echo "DMG signed successfully"

# Step 5: Notarize
echo ""
echo "=== Step 5: Submitting for Notarization ==="
echo "This may take a few minutes..."
xcrun notarytool submit "$DMG_FILE" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# Step 6: Staple notarization ticket
echo ""
echo "=== Step 6: Stapling Notarization Ticket ==="
xcrun stapler staple "$DMG_FILE"

# Step 7: Verify
echo ""
echo "=== Step 7: Verifying Signature ==="
xcrun stapler validate "$DMG_FILE"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_FILE"
echo "DMG is signed and notarized"

# Step 8: Generate checksum
echo ""
echo "=== Step 8: Generating SHA256 checksum ==="
shasum -a 256 "$DMG_FILE" > "$DMG_FILE.sha256"
echo "Checksum: $(cat "$DMG_FILE.sha256")"

# Step 9: Upload to GitHub Release
echo ""
echo "=== Step 9: Creating Tag and Uploading to GitHub Release ==="

TAG="v$VERSION"
echo "Tag: $TAG"

if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) not installed."
    echo "Install with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

# Create and push tag
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists locally."
else
    echo "Creating tag $TAG..."
    git tag "$TAG"
fi

echo "Pushing tag $TAG to origin..."
git push origin "$TAG" 2>/dev/null || echo "Tag already exists on remote."

# Generate release notes
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
if [ -n "$PREV_TAG" ]; then
    CHANGES=$(git log --pretty=format:"- %s" "$PREV_TAG"..HEAD --no-merges | head -20)
else
    CHANGES=$(git log --pretty=format:"- %s" -10 --no-merges)
fi

SHA256_VALUE=$(cat "$DMG_FILE.sha256" | awk '{print $1}')

RELEASE_NOTES="## What's New

$CHANGES

## Installation

\`\`\`bash
brew install --cask choru-k/tap/mungmung
\`\`\`

## Checksum

\`$SHA256_VALUE\`"

if gh release view "$TAG" &> /dev/null; then
    echo "Release $TAG exists. Uploading assets..."
    gh release upload "$TAG" "$DMG_FILE" "$DMG_FILE.sha256" --clobber
else
    echo "Creating new release $TAG..."
    gh release create "$TAG" \
        --title "MungMung $TAG" \
        --notes "$RELEASE_NOTES" \
        "$DMG_FILE" "$DMG_FILE.sha256"
fi

echo "Uploaded to: https://github.com/choru-k/mungmung/releases/tag/$TAG"

# Step 10: Update Homebrew Tap
echo ""
echo "=== Step 10: Updating Homebrew Tap ==="

HOMEBREW_TAP_DIRS=(
    "$HOME/Code/homebrew-tap"
    "$HOME/Projects/homebrew-tap"
    "$(dirname "$PROJECT_DIR")/homebrew-tap"
)

HOMEBREW_TAP_DIR=""
for dir in "${HOMEBREW_TAP_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -f "$dir/Casks/mungmung.rb" ]; then
        HOMEBREW_TAP_DIR="$dir"
        break
    fi
done

if [ -n "$HOMEBREW_TAP_DIR" ]; then
    echo "Found tap at: $HOMEBREW_TAP_DIR"
    cd "$HOMEBREW_TAP_DIR"

    sed -i '' "s/version \".*\"/version \"$VERSION\"/" Casks/mungmung.rb
    sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256_VALUE\"/" Casks/mungmung.rb

    git add Casks/mungmung.rb
    git commit -m "Update mungmung to v$VERSION" || echo "No changes to commit"
    git push origin main || git push origin master

    echo "Homebrew tap updated"
    cd "$PROJECT_DIR"
else
    echo "Homebrew tap not found. Update manually:"
    echo "   1. Clone/create: https://github.com/choru-k/homebrew-tap"
    echo "   2. Update Casks/mungmung.rb with:"
    echo "      version \"$VERSION\""
    echo "      sha256 \"$SHA256_VALUE\""
fi

# Summary
echo ""
echo "=== Distribution Complete ==="
echo "Files created:"
ls -lh "$DIST_DIR"
echo ""
echo "SHA256: $SHA256_VALUE"
echo ""
echo "App is signed and notarized — users can install without Gatekeeper warnings"
```

### `Scripts/create_dmg.sh`

```bash
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
```

### `Casks/mungmung.rb`

```ruby
# Homebrew Cask formula for MungMung
#
# Personal Tap Installation:
#   brew tap choru-k/tap
#   brew install --cask mungmung
#
# To test locally:
#   brew install --cask ./Casks/mungmung.rb

cask "mungmung" do
  version "0.1.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/choru-k/mungmung/releases/download/v#{version}/MungMung-#{version}.dmg"
  name "MungMung"
  desc "Native macOS stateful notification manager with CLI"
  homepage "https://github.com/choru-k/mungmung"

  depends_on macos: ">= :sonoma"

  app "MungMung.app"

  # Symlink the CLI binary as 'mung'
  binary "#{appdir}/MungMung.app/Contents/MacOS/MungMung", target: "mung"

  zap trash: [
    "~/.local/share/mung",
  ]

  caveats <<~EOS
    MungMung requires notification permissions.
    Grant permission when prompted on first run.

    CLI usage:
      mung add --title "Hello" --message "World"
      mung list
      mung help
  EOS
end
```

### Makefile Updates

Update the `release` target in the Makefile (from Task 1):

```makefile
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
```

## Verification

1. **Scripts are executable:**
   ```bash
   chmod +x Scripts/distribute.sh Scripts/create_dmg.sh Scripts/create_app_bundle.sh
   ```

2. **App bundle creation:**
   ```bash
   swift build -c release
   Scripts/create_app_bundle.sh .build/release/MungMung dist
   ls -la dist/MungMung.app/Contents/MacOS/
   ls -la dist/MungMung.app/Contents/Info.plist
   ```

3. **App bundle runs:**
   ```bash
   dist/MungMung.app/Contents/MacOS/MungMung help
   ```

4. **Code signing (requires Developer ID cert):**
   ```bash
   codesign --force --options runtime \
       --sign "Developer ID Application: Cheol Kang (ESURPGU29C)" \
       --entitlements MungMung.entitlements \
       dist/MungMung.app
   codesign --verify --verbose dist/MungMung.app
   ```

5. **DMG creation:**
   ```bash
   Scripts/create_dmg.sh dist/MungMung.app dist 0.1.0
   ls -la dist/MungMung-0.1.0.dmg
   ```

6. **Full pipeline (dry run — skip notarize):**
   Comment out the notarization steps in distribute.sh, then:
   ```bash
   make release VERSION=0.1.0
   ```

7. **Cask formula syntax:**
   ```bash
   brew style Casks/mungmung.rb  # if brew-ruby is available
   ```

## Architecture Context

The distribution pipeline takes the SPM build output and produces an installable package:

```
swift build -c release
    │
    ▼
.build/release/MungMung (plain binary)
    │
    ▼  Scripts/create_app_bundle.sh
dist/MungMung.app/
├── Contents/
│   ├── MacOS/MungMung     ← binary
│   ├── Info.plist          ← from Resources/Info.plist
│   └── PkgInfo            ← "APPL????"
    │
    ▼  codesign
    │
    ▼  Scripts/create_dmg.sh
dist/MungMung-0.1.0.dmg
    │
    ▼  codesign + notarytool + stapler
    │
    ▼  gh release create
GitHub Release: v0.1.0
    │
    ▼  Homebrew tap update
brew install --cask choru-k/tap/mungmung
    │
    ▼  Cask installs
/Applications/MungMung.app
/usr/local/bin/mung → MungMung.app/Contents/MacOS/MungMung
```

**Notarization keychain profile setup (one-time):**
Before first release, store Apple ID credentials:
```bash
xcrun notarytool store-credentials MungMungNotarization \
    --apple-id "your-apple-id@email.com" \
    --team-id "ESURPGU29C"
# Enter app-specific password when prompted
```

**Homebrew cask `binary` stanza:** This is the key — it creates a symlink from `/usr/local/bin/mung` to `MungMung.app/Contents/MacOS/MungMung`, giving users the `mung` CLI command after `brew install`.
