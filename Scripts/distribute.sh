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
