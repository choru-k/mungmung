# mungmung — Spec

## What it is

A native macOS app that manages stateful notifications via CLI. No wrapper around terminal-notifier — built from scratch with Swift and `UNUserNotificationCenter`.

**Name:** mungmung (CLI command: `mung`)
**Repo:** `choru-k/mungmung`

## Why native app, not shell script

- Full control over notification appearance (icons, action buttons, categories)
- No `-sender` vs `-execute` conflict (terminal-notifier limitation)
- Click handling via `UNUserNotificationCenterDelegate` — reliable, no hacks
- Can query/manage its own notifications
- Custom app icon in notifications
- No third-party dependency (no terminal-notifier)

## Core concept

**Stateful notification manager.** Every notification is backed by a JSON state file. The notification can be dismissed from any interface (macOS notification click, sketchybar click, CLI) and all stay in sync through the shared state directory.

## CLI interface

Single binary embedded in the app bundle. Symlinked to PATH as `mung`.

```
mung add     --title "..." --message "..." [--on-click "cmd"] [--icon "🔔"] [--group "name"] [--sound "default"]
mung list    [--json] [--group "name"]
mung done    <id> [--run]
mung count   [--group "name"]
mung clear   [--group "name"]
mung version
mung help
```

### Subcommand behavior

**`mung add`** — Create alert + fire native notification
- Generates unique ID
- Writes state file to `$MUNG_DIR/alerts/<id>.json`
- Sends macOS notification via `UNUserNotificationCenter`
- Notification `userInfo` carries the alert ID + on_click command
- Triggers sketchybar event: `sketchybar --trigger mung_alert_change`
- Prints ID to stdout
- App exits after sending

**`mung done <id> [--run]`** — Dismiss alert
- Reads + removes state file
- Removes notification from Notification Center (`UNUserNotificationCenter.removePendingNotificationRequests` / `removeDeliveredNotifications`)
- If `--run`: executes `on_click` command in background
- Triggers sketchybar event
- App exits after cleanup

**`mung list [--json]`** — List pending alerts
- Reads all state files from `$MUNG_DIR/alerts/`
- `--json`: output as JSON array
- Default: human-readable table (ID, group, icon, title, age)

**`mung count`** — Print number of pending alerts
- For sketchybar consumption

**`mung clear`** — Dismiss all (or by group)

## State

### Directory

`$MUNG_DIR` env var, defaults to `~/.local/share/mung`.
Alerts stored in `$MUNG_DIR/alerts/<id>.json`.

### State file format

```json
{
  "id": "1738000000_a1b2c3d4",
  "title": "Claude Code",
  "message": "Waiting for input",
  "on_click": "aerospace workspace Terminal",
  "icon": "🤖",
  "group": "claude",
  "sound": "default",
  "created_at": "2026-02-09T12:00:00Z"
}
```

Plain JSON. Any tool can read/write these files.

## App architecture

### Swift, headless macOS app

- `LSUIElement = true` (no Dock icon, no menu bar)
- Entry point detects subcommand from `CommandLine.arguments`
- Two modes:
  1. **CLI mode** — `add`, `done`, `list`, `count`, `clear`, `help`, `version`
  2. **Notification callback mode** — launched by macOS when user clicks a notification

### Lifecycle: launch on demand

- App launches per CLI call, does its work, exits
- When user clicks a notification, **macOS relaunches** the app automatically
- `AppDelegate.applicationDidFinishLaunching` checks `launchUserNotificationUserInfoKey` for click data
- On click: reads `on_click` from `userInfo`, executes it, calls `mung done <id>`, exits
- No daemon, no background process, no LaunchAgent

### Notification click handling

macOS delivers the click to `UNUserNotificationCenterDelegate.didReceive`:
1. Extract alert ID + on_click from notification's `userInfo`
2. Run `on_click` command (via `Process` / shell)
3. Remove state file
4. Trigger sketchybar event
5. Exit

### Notification features (native UNUserNotificationCenter)

- Custom title, subtitle, message
- Custom icon (app icon shows in notification — can be set per-notification via `UNNotificationContent`)
- Sound (system sounds or custom)
- Notification categories with action buttons (future: "Dismiss", "Snooze")
- Thread identifiers for grouping related notifications
- `userInfo` dict carries all alert metadata

## Sketchybar integration

Not built into the app. Sketchybar plugin is a separate shell script that:
- Subscribes to `mung_alert_change` custom event
- Reads state files from `$MUNG_DIR/alerts/`
- Creates/removes dynamic sketchybar items (one per alert)
- Each item's click_script: `mung done <id> --run`

The app just triggers `sketchybar --trigger mung_alert_change` after any state change.

Example plugin lives in `examples/sketchybar-plugin.sh`. User's actual plugin lives in their dotfiles.

## Distribution

- Homebrew cask (it's an .app bundle)
- Sign + notarize with Developer ID (reuse existing pipeline from ClaudeZellijWhip)
- `brew install --cask choru-k/tap/mungmung`
- Post-install: symlink `mung` → `MungMung.app/Contents/MacOS/mung` (or Homebrew `binary` stanza)

## Dotfiles integration

| File | Change |
|------|--------|
| `Brewfile` | Replace `claude-zellij-whip` cask with `mungmung` cask |
| `claude/settings.json` | Update notification hooks to use `mung add` |
| `sketchybar/plugins/mung_alerts.sh` | New — sketchybar plugin |
| `sketchybar/sketchybarrc` | Register `mung_alert_change` event + manager item |
| `symlink.sh` | Add symlink for `mung` CLI if not handled by Homebrew |

## Example usage

```bash
# Generic notification
mung add --title "Build" --message "Deploy ready" --on-click "open https://github.com"

# Claude Code hook (in settings.json)
mung add --title "Claude Code" --message "Waiting: ${CLAUDE_PROJECT_DIR##*/}" \
  --group claude --icon "🤖" --sound default \
  --on-click "aerospace workspace Terminal"

# Check alerts
mung list
mung count

# Dismiss from CLI
mung done 1738000000_a1b2c3d4

# Dismiss + run action from CLI
mung done 1738000000_a1b2c3d4 --run

# Clear all claude alerts
mung clear --group claude
```

## What's NOT in scope

- No GUI preferences window
- No menu bar icon (that's sketchybar's job)
- No built-in terminal/zellij/tmux logic (on_click is user-defined)
- No network/remote notifications
- No notification history/persistence after done
