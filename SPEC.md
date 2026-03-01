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
mung add     --title "..." --message "..." [--on-click "cmd"] [--icon "..."] [--tag "name" ...]
             [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."] [--sound "default"]
mung list    [--json] [--tag "name" ...] [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."]
mung done    <id> [--run]
mung count   [--tag "name" ...] [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."]
mung clear   [--tag "name" ...] [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."]
mung doctor  [--json]
mung version
mung help
```

### Agent metadata contract v1

For agent-oriented integrations (Pi, Claude, and future adapters), v1 defines first-class metadata flags.
This is the primary contract for adapter implementations.

```
mung add     --title "..." --message "..." [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."]
             [--on-click "cmd"] [--icon "..."] [--tag "name" ...] [--sound "default"]
mung list    [--json] [--tag "name" ...] [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."]
mung count   [--tag "name" ...] [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."]
mung clear   [--tag "name" ...] [--source "..."] [--session "..."] [--kind "..."] [--dedupe-key "..."]
```

| Flag | Purpose | Example |
|------|---------|---------|
| `--source` | Adapter/source identity | `pi-agent`, `claude` |
| `--session` | Session/run correlation key | `01HT...` |
| `--kind` | Alert class (free-form, adapter-defined) | `update`, `action` |
| `--dedupe-key` | Replace previous matching alert before add | `pi:update:$PI_SESSION_ID` |

#### Metadata and filtering rules

1. **Metadata is first-class:** agent adapters should set `--source`, `--session`, and `--kind` on `mung add`.
2. **Metadata persistence:** `source`, `session`, and `kind` are persisted as dedicated alert fields.
3. **Tags are optional labels:** `--tag` remains available for custom grouping, independent of metadata fields.
4. **Filtering logic:**
   - Repeated flags within one dimension are OR-matched.
   - Different dimensions are AND-combined.
   - Example: `--tag pi-agent --session abc --kind action`
     means `(tag in {pi-agent}) AND (session == abc) AND (kind == action)`.
5. **Dedupe semantics:**
   - `--dedupe-key` replaces existing matching alerts before inserting the new alert.
   - If `--session` is provided, replacement scope is limited to that session + dedupe key.
   - Without `--session`, replacement scope is global to the dedupe key.
6. **JSON output:** existing keys remain; metadata keys are included when present.

### Adapter integration contract (Phase 4 kit)

For Pi/Claude-style adapters, use this baseline for `mung add`:

| Category | Fields/flags | Requirement |
|---|---|---|
| Core payload | `title`, `message` (`--title`, `--message`) | Required |
| Adapter identity | `source` (`--source`) | Required |
| Session identity | `session` (`--session`) | Required |
| Event classification | `kind` (`--kind`) | Required |
| Dedupe lane | `dedupe_key` (`--dedupe-key`) | Strongly recommended |
| Action hook | `on_click` (`--on-click`) | Optional |
| UX metadata | `icon`, `sound`, `tags` (`--icon`, `--sound`, `--tag`) | Optional |

### Adapter lifecycle expectations

Reference lifecycle mapping for agent adapters:

| Adapter event | Recommended operation |
|---|---|
| Session start / agent start | `mung clear --source <adapter> --session <id>` |
| Regular turn/update | `mung add ... --kind update --dedupe-key "<adapter>:update:<id>"` |
| Confirmation needed | `mung add ... --kind action --dedupe-key "<adapter>:action:<id>"` |
| Confirmation resolved | `mung clear --source <adapter> --session <id> --kind action` |
| Session shutdown | `mung clear --source <adapter> --session <id>` |

### Adapter upgrade notes

For adapters that currently rely on tags only:
1. Add first-class metadata fields (`source`, `session`, `kind`) on `add`.
2. Introduce stable `dedupe_key` values for update/action alert lanes.
3. Move cleanup/filtering calls to metadata filters (source/session/kind).
4. Keep tags only for custom labels or UI grouping.

### Subcommand behavior

**`mung add`** — Create alert + fire native notification
- Generates unique ID
- If `--dedupe-key` is set, removes previous matching alert(s) before save
  - scoped by session when `--session` is provided
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

**`mung list [--json] [--tag ...] [--source ...] [--session ...] [--kind ...] [--dedupe-key ...]`** — List pending alerts
- Reads all state files from `$MUNG_DIR/alerts/`
- Supports tag and metadata filters (see v1 filtering rules above)
- `--json`: output as JSON array
- Default: human-readable table (ID, tags, icon, title, age)

**`mung count [--tag ...] [--source ...] [--session ...] [--kind ...] [--dedupe-key ...]`** — Print number of pending alerts
- Applies the same filter semantics as `list`
- For sketchybar or adapter consumption

**`mung clear [--tag ...] [--source ...] [--session ...] [--kind ...] [--dedupe-key ...]`** — Dismiss matching alerts
- Applies the same filter semantics as `list`
- No filters means clear all alerts

**`mung doctor [--json]`** — Print runtime diagnostics
- Reports executable/bundle context and notification availability
- Reports current state directory, alerts directory status, and alert count
- Reports resolved on_click shell context and debug flag status
- `--json` emits a machine-readable diagnostics payload

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
  "tags": ["claude"],
  "source": "claude",
  "session": "cc-20260301-abc",
  "kind": "update",
  "dedupe_key": "claude:update:cc-20260301-abc",
  "sound": "default",
  "created_at": "2026-02-09T12:00:00Z"
}
```

Plain JSON. Any tool can read/write these files.
`source`, `session`, `kind`, and `dedupe_key` are optional metadata fields.

## App architecture

### Swift macOS app (CLI + menu bar)

- `LSUIElement = true` (no Dock icon; app lives in menu bar)
- Entry point detects subcommand from `CommandLine.arguments`
- Modes:
  1. **CLI mode** — `add`, `done`, `list`, `count`, `clear`, `help`, `version`
  2. **Menu bar mode** — no CLI subcommand, run SwiftUI menu bar app
  3. **Notification callback path** — click delivered via notification delegate

### Lifecycle: launch on demand

- App launches per CLI call, does its work, exits
- When user clicks a notification, **macOS relaunches** the app automatically if needed
- The app registers `UNUserNotificationCenterDelegate` and handles clicks in `didReceive`
- Click path reuses `Commands.done(id: ..., run: ...)` for consistent behavior
- No daemon, no background process, no LaunchAgent

### Notification click handling

macOS delivers the click to `UNUserNotificationCenterDelegate.didReceive`.
Click handling reuses the same command path as CLI dismissal:
1. Extract alert ID from notification `userInfo`
2. Determine `run` (`true` for default body click)
3. Delegate to `Commands.done(id: ..., run: ...)`
4. `Commands.done` performs state removal, notification cleanup, optional `on_click`, and sketchybar trigger

### on_click execution context

When `on_click` executes, shell context resolution is:
1. `$MUNG_ON_CLICK_SHELL` (if executable)
2. `$SHELL` (if executable)
3. fallback `/bin/sh`

Controls:
- `$MUNG_ON_CLICK_CWD` — set working directory for action execution (must exist)
- `$MUNG_DEBUG_ACTIONS=1` — print action/sketchybar execution failures to stderr
- `$MUNG_DEBUG_LIFECYCLE=1` — print add/done/clear lifecycle diagnostics to stderr

### Platform behavior matrix (mung-notify reference focus script)

The matrix below describes known focus behavior tiers from the Pi `mung-notify` adapter (`scripts/mung-focus.sh`).
This is adapter-level behavior, not a universal mung core guarantee.

| Runtime combination | Tier | Guarantee summary |
|---|---|---|
| WezTerm | exact | Deterministic return via WezTerm pane ID |
| WezTerm + tmux | exact | Deterministic WezTerm + tmux targeting |
| WezTerm + zellij | exact | Deterministic WezTerm + zellij targeting |
| Ghostty | app_only | Foreground Ghostty app only |
| Ghostty (single tab) + tmux | practical_exact | Deterministic if single-tab invariant holds |
| Ghostty (single tab) + zellij | practical_exact | Deterministic if single-tab invariant holds |
| Ghostty (multi tab) + tmux | best_effort | tmux context targeted; exact Ghostty tab not guaranteed |
| Ghostty (multi tab) + zellij | best_effort | zellij context targeted; exact Ghostty tab not guaranteed |

### Notification features (native UNUserNotificationCenter)

- Custom title, subtitle, message
- Custom icon — emoji, SF Symbol name (e.g. `"bell.fill"`), or image file path (e.g. `"/path/to/icon.png"`); rendered as notification attachment thumbnail
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

# Pi adapter task update (replace prior session update)
mung add --title "Pi task update" --message "Pi finished this turn" \
  --source pi-agent --session "$PI_SESSION_ID" --kind update \
  --dedupe-key "pi:update:$PI_SESSION_ID" \
  --icon "🦴" --sound default \
  --on-click "bash -lc '~/.pi/agent/extensions/mung-notify/scripts/mung-focus.sh ...'"

# Claude adapter confirmation-needed alert
mung add --title "Pi needs your confirmation" --message "Agent asks for input" \
  --source claude --session "$CLAUDE_SESSION_ID" --kind action \
  --icon "🤖" --sound default

# Query by metadata (new) or by tags (existing)
mung list --session "$PI_SESSION_ID" --kind update --json
mung count --tag pi-needs-action

# Dismiss from CLI
mung done 1738000000_a1b2c3d4

# Dismiss + run action from CLI
mung done 1738000000_a1b2c3d4 --run

# Session-scoped cleanup
mung clear --source pi-agent --session "$PI_SESSION_ID"

# Runtime diagnostics
mung doctor
mung doctor --json
```

## Release hardening verification

Recommended pre-release checks:
1. `swift test`
2. `swift build -c release`
3. `.build/release/MungMung doctor --json`
4. `make verify-release`
5. Validate reference integration flows from `Tests/MungMungTests/CLIIntegrationTests.swift`.

## What's NOT in scope

- No full Dock-based primary window workflow (menu bar utility app only)
- No built-in terminal/zellij/tmux targeting logic in core (`on_click` remains user/adapter-defined)
- No network/remote notification relay
- No cross-device sync
- No notification history/persistence after done
