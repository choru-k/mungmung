# Task 7: Shell Helper & Sketchybar Integration

## Background

mungmung needs to run shell commands in two scenarios:
1. **`on_click` execution** — when the user clicks a notification or runs `mung done <id> --run`, the stored `on_click` command runs via `/bin/sh -c`
2. **Sketchybar trigger** — after any state change (`add`, `done`, `clear`), the app runs `sketchybar --trigger mung_alert_change` so sketchybar plugins can update their display

The sketchybar integration is intentionally decoupled — the app only fires a trigger event. The actual sketchybar plugin that subscribes to this event and renders alert items is a separate shell script that lives in the user's dotfiles. This task provides a reference plugin at `examples/sketchybar-plugin.sh`.

**Reference:** The existing `~/dotfiles/sketchybar/plugins/ai_sessions.sh` shows the pattern — it reads JSON status files, counts them, and updates sketchybar labels. The mungmung plugin follows the same approach but reads from `$MUNG_DIR/alerts/`.

**Reference:** The `~/dotfiles/sketchybar/sketchybarrc` shows how to register custom events and subscribe items to them (e.g., `sketchybar --add event aerospace_workspace_change`).

## Dependencies

- **Task 1** (Project Setup) — Package.swift and directory structure must exist

## Files to Create

| File | Purpose |
|------|---------|
| `Sources/MungMung/Services/ShellHelper.swift` | Run shell commands (on_click, sketchybar trigger) |
| `examples/sketchybar-plugin.sh` | Reference sketchybar plugin for mungmung alerts |

## Implementation

### `Sources/MungMung/Services/ShellHelper.swift`

```swift
import Foundation

/// Helper for running shell commands.
///
/// Used by:
/// - Commands.add/done/clear → triggerSketchybar() after state changes
/// - Commands.done (--run) → execute(command:) for on_click
/// - AppDelegate click handler → execute(command:) for on_click
enum ShellHelper {

    /// Trigger the sketchybar custom event so plugins can update.
    ///
    /// Runs: `sketchybar --trigger mung_alert_change`
    ///
    /// This is a fire-and-forget call. If sketchybar is not running
    /// or the command fails, we silently ignore the error — the CLI
    /// shouldn't fail just because sketchybar isn't active.
    static func triggerSketchybar() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sketchybar", "--trigger", "mung_alert_change"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        // Don't wait — fire and forget
    }

    /// Execute a shell command via `/bin/sh -c "command"`.
    ///
    /// Used for `on_click` actions from alert state files.
    /// The command runs in the background — the app doesn't wait for it to complete.
    ///
    /// - Parameter command: The shell command string to execute
    static func execute(command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        // Don't wait — fire and forget
    }
}
```

### `examples/sketchybar-plugin.sh`

```bash
#!/bin/bash
# MungMung Alerts Plugin for Sketchybar
# Reference implementation — copy to your dotfiles and customize.
#
# This plugin:
# 1. Subscribes to the `mung_alert_change` custom event
# 2. Reads alert state files from $MUNG_DIR/alerts/
# 3. Updates a sketchybar label showing alert count and icons
#
# Setup in your sketchybarrc:
# ─────────────────────────────────────────────────────────
#   # Register the custom event
#   sketchybar --add event mung_alert_change
#
#   # Add the mungmung alerts item
#   sketchybar --add item mung_alerts right \
#     --set mung_alerts \
#     icon="🔔" \
#     icon.padding_left=8 \
#     icon.padding_right=4 \
#     label="0" \
#     label.padding_right=8 \
#     background.drawing=on \
#     click_script="mung list" \
#     script="$PLUGIN_DIR/mung_alerts.sh" \
#     --subscribe mung_alerts mung_alert_change
# ─────────────────────────────────────────────────────────
#
# Clicking the item opens a terminal with `mung list`.
# You can change click_script to whatever suits your workflow.

# Colors (Catppuccin Macchiato — match your sketchybarrc)
TEXT_COLOR=0xffcdd6f4    # Text (active)
SUBTEXT_COLOR=0xff6c7086 # Subtext (inactive/zero)
ACCENT_COLOR=0xff89b4fa  # Blue (alerts present)

# State directory
MUNG_DIR="${MUNG_DIR:-$HOME/.local/share/mung}"
ALERTS_DIR="$MUNG_DIR/alerts"

# Count alert files
count=0
if [[ -d "$ALERTS_DIR" ]]; then
    for file in "$ALERTS_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        ((count++))
    done
fi

# Build label
if (( count == 0 )); then
    LABEL="0"
    LABEL_COLOR=$SUBTEXT_COLOR
    ICON_COLOR=$SUBTEXT_COLOR
else
    LABEL="$count"
    LABEL_COLOR=$TEXT_COLOR
    ICON_COLOR=$ACCENT_COLOR
fi

# Update sketchybar item
sketchybar --set "$NAME" \
    label="$LABEL" \
    label.color=$LABEL_COLOR \
    icon.color=$ICON_COLOR
```

### Sketchybar Configuration Snippet

To use the plugin, add this to your `sketchybarrc`:

```bash
# =============================================================================
# MungMung Alerts
# =============================================================================

# Register custom event (mungmung triggers this after state changes)
sketchybar --add event mung_alert_change

# Alert count item
sketchybar --add item mung_alerts right \
  --set mung_alerts \
  icon="🔔" \
  icon.font="JetBrainsMono Nerd Font:Bold:14.0" \
  icon.padding_left=8 \
  icon.padding_right=4 \
  label="0" \
  label.padding_right=8 \
  background.drawing=on \
  script="$PLUGIN_DIR/mung_alerts.sh" \
  --subscribe mung_alerts mung_alert_change
```

## Verification

1. **Build compiles:**
   ```bash
   swift build
   ```

2. **Test sketchybar trigger:**
   ```bash
   # If sketchybar is running:
   sketchybar --add event mung_alert_change  # register event first
   .build/debug/MungMung add --title "Test" --message "Trigger test"
   # Check that sketchybar received the event (plugin would run)
   ```

3. **Test on_click execution:**
   ```bash
   .build/debug/MungMung add --title "Test" --message "Run test" \
     --on-click "echo success > /tmp/mung-onclick-test"
   ID=$(.build/debug/MungMung list --json | jq -r '.[0].id')
   .build/debug/MungMung done "$ID" --run
   cat /tmp/mung-onclick-test
   # Should contain: success
   ```

4. **Test example plugin directly:**
   ```bash
   chmod +x examples/sketchybar-plugin.sh
   NAME=mung_alerts MUNG_DIR=/tmp/mung-test examples/sketchybar-plugin.sh
   # Should call sketchybar --set mung_alerts ... (will fail if sketchybar not running, that's OK)
   ```

5. **Test sketchybar trigger when sketchybar is not running:**
   ```bash
   # Stop sketchybar, then run:
   .build/debug/MungMung add --title "Test" --message "No sketchybar"
   # Should not error — fire-and-forget
   ```

## Architecture Context

The sketchybar integration is a one-way trigger pattern:

```
mungmung app                          sketchybar
─────────────                         ──────────
add/done/clear
    │
    ├── AlertStore (write state)
    ├── NotificationManager
    └── ShellHelper.triggerSketchybar()
            │
            │  sketchybar --trigger mung_alert_change
            │
            ▼
        sketchybar receives event
            │
            ▼
        mung_alerts plugin runs
            │
            ├── reads $MUNG_DIR/alerts/*.json
            ├── counts alerts
            └── sketchybar --set mung_alerts label="N"
```

This decoupled design means:
- mungmung works fine without sketchybar
- The plugin is fully customizable — users can show alert details, icons, per-group counts, etc.
- The state files are the source of truth — both the app and the plugin read them
- The trigger is just a "something changed" signal — the plugin re-reads state every time

**Reference patterns from existing dotfiles:**
- `sketchybar/plugins/ai_sessions.sh` — reads JSON files from status directories, counts active sessions, updates labels with colors. The mungmung plugin follows the same pattern but is simpler (just count files).
- `sketchybar/sketchybarrc` — shows how to register custom events (`--add event`), create items (`--add item`), and subscribe to events (`--subscribe`).
