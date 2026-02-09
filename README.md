# mungmung

A native macOS app that manages stateful notifications via CLI. Built from scratch with Swift and `UNUserNotificationCenter` — no terminal-notifier dependency.

**CLI command:** `mung`

## Why

- Full control over notification appearance (icons, action buttons, sound)
- Reliable click handling via `UNUserNotificationCenterDelegate`
- Every notification backed by a JSON state file — dismissible from notification click, sketchybar, or CLI
- No daemon or background process — launches on demand, does work, exits

## Install

```bash
brew install --cask choru-k/tap/mungmung
```

The `mung` CLI is symlinked automatically.

## Usage

```
mung add     --title "..." --message "..." [--on-click "cmd"] [--icon "..."] [--group "name"] [--sound "default"]
mung list    [--json] [--group "name"]
mung done    <id> [--run]
mung count   [--group "name"]
mung clear   [--group "name"]
mung version
mung help
```

## Examples

```bash
# Simple notification
mung add --title "Build" --message "Deploy ready" --on-click "open https://github.com"

# Notification with group and icon
mung add --title "Claude Code" --message "Waiting for input" \
  --group claude --icon "🤖" --sound default \
  --on-click "aerospace workspace Terminal"

# List all pending alerts
mung list
mung list --json

# Get count (useful for sketchybar)
mung count

# Dismiss an alert
mung done 1738000000_a1b2c3d4

# Dismiss and run its on-click action
mung done 1738000000_a1b2c3d4 --run

# Clear all alerts in a group
mung clear --group claude
```

## How it works

1. `mung add` writes a JSON state file to `~/.local/share/mung/alerts/` and fires a native macOS notification
2. When user clicks the notification, macOS relaunches the app — it reads the action from `userInfo`, executes `on_click`, removes the state file
3. After any state change, the app triggers `sketchybar --trigger mung_alert_change` so sketchybar plugins can update

State directory is configurable via `$MUNG_DIR` (defaults to `~/.local/share/mung`).

## Sketchybar integration

The app doesn't include a sketchybar plugin — it just triggers the `mung_alert_change` event. Your sketchybar config subscribes to that event and reads state files to render alert items. See `examples/sketchybar-plugin.sh` for a reference implementation.

## Spec

See [SPEC.md](SPEC.md) for the full technical specification.

## License

MIT
