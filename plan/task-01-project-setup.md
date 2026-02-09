# Task 1: Project Setup & App Scaffold

## Background

mungmung is a native macOS app that manages stateful notifications via CLI (`mung`). It's a headless app (no Dock icon, no menu bar) that launches on demand — either from the CLI or when macOS relaunches it after a notification click. It uses `UNUserNotificationCenter` for native notifications and stores state as JSON files on disk.

This task creates the foundational project structure: SPM package, Info.plist, entitlements, the app entry point with a minimal AppDelegate, and the Makefile for building.

**Reference project:** PasteFence at `~/Desktop/choru/pastefence/` follows the same SPM executable target pattern.

## Dependencies

None — this is the first task.

## Files to Create

| File | Purpose |
|------|---------|
| `Package.swift` | SPM package manifest |
| `Sources/MungMung/MungMungApp.swift` | `@main` entry point + AppDelegate shell |
| `Resources/Info.plist` | Bundle configuration (LSUIElement=true) |
| `MungMung.entitlements` | App entitlements (notifications) |
| `Makefile` | Build/test/run/release targets |

## Implementation

### `Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MungMung",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MungMung", targets: ["MungMung"])
    ],
    targets: [
        .executableTarget(
            name: "MungMung",
            path: "Sources/MungMung",
            resources: [
                .copy("../../Resources/Info.plist")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
```

Key differences from PasteFence:
- **No external dependencies** — no ArgumentParser, no KeyboardShortcuts, no MLX. The CLI is simple enough to parse by hand.
- Resources include Info.plist for the app bundle.

### `Resources/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MungMung</string>
    <key>CFBundleDisplayName</key>
    <string>MungMung</string>
    <key>CFBundleIdentifier</key>
    <string>com.choru-k.mungmung</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>MungMung</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Cheol Kang. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
```

Key settings:
- **`LSUIElement = true`** — headless app, no Dock icon, no menu bar
- **`NSUserNotificationAlertStyle = alert`** — ensures notifications show as banners/alerts (not silent)
- **Bundle ID:** `com.choru-k.mungmung`

### `MungMung.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

Sandbox is disabled because:
- The app needs to read/write arbitrary files in `$MUNG_DIR` (defaults to `~/.local/share/mung`)
- The app needs to execute arbitrary shell commands (`on_click`, `sketchybar --trigger`)
- It's a CLI tool distributed via Homebrew cask, not the App Store

### `Sources/MungMung/MungMungApp.swift`

This is a shell that will be expanded in Tasks 5 and 6. For now it provides the minimal structure.

```swift
import AppKit
import UserNotifications

// MARK: - App Entry Point

@main
struct MungMungApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        // Check if launched from notification click
        // (expanded in Task 6)

        // Parse CLI arguments and dispatch
        // (expanded in Task 5)
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty {
            Commands.help()
            exit(0)
        }

        // Placeholder — will be replaced by CLIParser.route() in Task 5
        print("mungmung: not yet implemented")
        exit(0)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // Notification click handler (expanded in Task 6)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Placeholder — expanded in Task 6
        completionHandler()
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// Placeholder namespace for commands — replaced in Task 5
enum Commands {
    static func help() {
        print("""
        Usage: mung <command> [options]

        Commands:
          add      Create alert and send notification
          done     Dismiss alert by ID
          list     List pending alerts
          count    Print alert count
          clear    Dismiss all alerts
          version  Print version
          help     Show this help
        """)
    }
}
```

### `Makefile`

```makefile
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
```

## Verification

1. **Build compiles:**
   ```bash
   cd ~/Desktop/choru/mungmung
   swift build
   ```
   Should produce `.build/debug/MungMung` with no errors.

2. **Help output works:**
   ```bash
   .build/debug/MungMung help
   ```
   Should print the usage message.

3. **Makefile works:**
   ```bash
   make build-debug
   make run ARGS=help
   ```

4. **Info.plist is valid:**
   ```bash
   plutil -lint Resources/Info.plist
   ```

## Architecture Context

```
mungmung/
├── Package.swift              ← SPM manifest, executable target, no deps
├── Sources/MungMung/
│   ├── MungMungApp.swift      ← @main entry, AppDelegate shell
│   ├── Models/                ← (Task 2) Alert.swift
│   ├── Services/              ← (Tasks 2,4,7) AlertStore, NotificationManager, ShellHelper
│   └── CLI/                   ← (Tasks 3,5) CLIParser, Commands
├── Resources/
│   └── Info.plist             ← LSUIElement=true, bundle ID, version
├── MungMung.entitlements      ← Sandbox disabled
├── Makefile                   ← build/run/release targets
├── Scripts/                   ← (Task 8) distribute.sh, create_dmg.sh
├── Casks/                     ← (Task 8) Homebrew cask formula
└── examples/                  ← (Task 7) sketchybar-plugin.sh
```

The app is a headless macOS executable (no GUI, no Dock icon). It processes CLI arguments, does its work (send notification, write/read state files, execute shell commands), and exits. When macOS relaunches it after a notification click, the AppDelegate handles the click and exits.
