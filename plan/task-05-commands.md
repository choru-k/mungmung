# Task 5: Command Implementations

## Background

mungmung has 7 CLI subcommands that wire together the AlertStore (Task 2), NotificationManager (Task 4), ShellHelper (Task 7), and CLIParser (Task 3). This task implements the actual business logic for each command and updates the app entry point to use the parser.

The commands are: `add`, `done`, `list`, `count`, `clear`, `version`, `help`.

Every state-changing command (`add`, `done`, `clear`) triggers `sketchybar --trigger mung_alert_change` via ShellHelper so the sketchybar plugin can update its display.

## Dependencies

- **Task 2** (Alert Model & State Store) — `Alert` struct and `AlertStore` class
- **Task 3** (CLI Parser) — `CLIParser` for argument parsing and routing
- **Task 4** (Notification Manager) — `NotificationManager` for sending/removing notifications
- **Task 7** (Shell Helper & Sketchybar) — `ShellHelper` for executing `on_click` and triggering sketchybar

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `Sources/MungMung/CLI/Commands.swift` | Create | All 7 command implementations |
| `Sources/MungMung/MungMungApp.swift` | Modify | Wire up CLIParser in `main()` |

## Implementation

### `Sources/MungMung/CLI/Commands.swift`

```swift
import Foundation

/// All CLI command implementations.
///
/// Each method performs its work synchronously and calls `exit()` when done.
/// State-changing commands trigger `sketchybar --trigger mung_alert_change` via ShellHelper.
///
/// Commands:
/// - add: Create alert + send notification
/// - done: Dismiss alert by ID
/// - list: Print pending alerts
/// - count: Print alert count
/// - clear: Dismiss all (or by group)
/// - version: Print version string
/// - help: Print usage
enum Commands {

    private static let store = AlertStore()
    private static let notifications = NotificationManager()

    // MARK: - add

    /// Create a new alert, save state, send notification, trigger sketchybar.
    ///
    /// Usage: `mung add --title "..." --message "..." [--on-click "cmd"] [--icon "🔔"] [--group "name"] [--sound "default"]`
    ///
    /// Behavior:
    /// 1. Request notification permission (first time only, macOS remembers)
    /// 2. Create Alert with generated ID
    /// 3. Save state file to `$MUNG_DIR/alerts/<id>.json`
    /// 4. Send macOS notification with userInfo containing alert_id + on_click
    /// 5. Trigger sketchybar event
    /// 6. Print alert ID to stdout
    /// 7. Exit 0
    static func add(
        title: String,
        message: String,
        onClick: String?,
        icon: String?,
        group: String?,
        sound: String?
    ) {
        notifications.requestPermission()

        let alert = Alert(
            title: title,
            message: message,
            onClick: onClick,
            icon: icon,
            group: group,
            sound: sound
        )

        do {
            try store.save(alert)
        } catch {
            CLIParser.printError("failed to save alert: \(error.localizedDescription)")
            exit(1)
        }

        notifications.send(alert: alert)
        ShellHelper.triggerSketchybar()

        print(alert.id)
        exit(0)
    }

    // MARK: - done

    /// Dismiss an alert: remove state file, remove notification, optionally run on_click.
    ///
    /// Usage: `mung done <id> [--run]`
    ///
    /// Behavior:
    /// 1. Load and remove state file
    /// 2. If `--run` and alert has `on_click`: execute the command in background
    /// 3. Remove notification from Notification Center
    /// 4. Trigger sketchybar event
    /// 5. Exit 0
    static func done(id: String, run: Bool) {
        guard let alert = store.remove(id: id) else {
            CLIParser.printError("alert not found: \(id)")
            exit(1)
        }

        if run, let onClick = alert.onClick, !onClick.isEmpty {
            ShellHelper.execute(command: onClick)
        }

        notifications.remove(alertID: alert.id)
        ShellHelper.triggerSketchybar()

        exit(0)
    }

    // MARK: - list

    /// List pending alerts as human-readable table or JSON.
    ///
    /// Usage: `mung list [--json] [--group "name"]`
    ///
    /// Default output (human-readable table):
    /// ```
    /// ID                       GROUP    ICON  TITLE              AGE
    /// 1738000000_a1b2c3d4      claude   🤖    Claude Code        2m
    /// 1738000060_b2c3d4e5      build    🔨    Deploy ready       5m
    /// ```
    ///
    /// JSON output (`--json`):
    /// ```json
    /// [{"id": "...", "title": "...", ...}]
    /// ```
    static func list(json: Bool, group: String?) {
        let alerts = store.list(group: group)

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(alerts),
               let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            } else {
                print("[]")
            }
        } else {
            if alerts.isEmpty {
                print("No pending alerts.")
            } else {
                // Header
                print(String(format: "%-26s %-10s %-5s %-20s %s",
                    "ID", "GROUP", "ICON", "TITLE", "AGE"))

                for alert in alerts {
                    print(String(format: "%-26s %-10s %-5s %-20s %s",
                        alert.id,
                        alert.group ?? "-",
                        alert.icon ?? "-",
                        String(alert.title.prefix(20)),
                        alert.age))
                }
            }
        }

        exit(0)
    }

    // MARK: - count

    /// Print the number of pending alerts.
    ///
    /// Usage: `mung count [--group "name"]`
    ///
    /// Output: just the number (for sketchybar consumption).
    static func count(group: String?) {
        print(store.count(group: group))
        exit(0)
    }

    // MARK: - clear

    /// Remove all alerts (or all in a group).
    ///
    /// Usage: `mung clear [--group "name"]`
    ///
    /// Behavior:
    /// 1. Get all matching alerts
    /// 2. Remove their state files
    /// 3. Remove their notifications
    /// 4. Trigger sketchybar event
    /// 5. Print count of removed alerts
    /// 6. Exit 0
    static func clear(group: String?) {
        let removed = store.clear(group: group)
        let ids = removed.map { $0.id }

        notifications.remove(alertIDs: ids)
        ShellHelper.triggerSketchybar()

        print("Cleared \(removed.count) alert\(removed.count == 1 ? "" : "s").")
        exit(0)
    }

    // MARK: - version

    /// Print version string.
    ///
    /// Usage: `mung version`
    ///
    /// Reads CFBundleShortVersionString from Info.plist if available,
    /// otherwise falls back to hardcoded version.
    static func version() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
        print("mung \(version)")
        exit(0)
    }

    // MARK: - help

    /// Print usage information.
    ///
    /// Usage: `mung help` or `mung --help` or `mung -h` or `mung` (no args)
    static func help() {
        print("""
        Usage: mung <command> [options]

        Commands:
          add      Create alert and send notification
                   --title "..."       Alert title (required)
                   --message "..."     Alert message (required)
                   --on-click "cmd"    Command to run on notification click
                   --icon "🔔"         Icon emoji
                   --group "name"      Group name for filtering
                   --sound "default"   Notification sound

          done     Dismiss alert by ID
                   <id>                Alert ID (required)
                   --run               Execute on_click command

          list     List pending alerts
                   --json              Output as JSON
                   --group "name"      Filter by group

          count    Print number of pending alerts
                   --group "name"      Filter by group

          clear    Dismiss all alerts
                   --group "name"      Clear only this group

          version  Print version
          help     Show this help

        State directory: $MUNG_DIR (default: ~/.local/share/mung)
        """)
        exit(0)
    }
}
```

### `Sources/MungMung/MungMungApp.swift` (Modified)

Update the entry point to use CLIParser:

```swift
import AppKit
import UserNotifications

@main
struct MungMungApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        // Set up notification delegate before anything else
        UNUserNotificationCenter.current().delegate = delegate

        // Check if launched from notification click (Task 6 handles this)
        // When macOS relaunches the app for a notification click, it calls
        // applicationDidFinishLaunching, which then receives the notification
        // response via the delegate method. We need to run the run loop briefly
        // to allow this to happen.
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty {
            // No CLI args — might be a notification click relaunch.
            // Run the event loop briefly to receive the notification callback.
            // If no callback comes, show help and exit.
            let runResult = CFRunLoopRunInMode(.defaultMode, 1.0, false)
            if runResult == .timedOut {
                // No notification callback — user just ran `mung` with no args
                Commands.help()
            }
            exit(0)
        }

        // Parse and route CLI command
        let invocation = CLIParser.parse(args)
        CLIParser.route(invocation)

        // route() calls exit() — this line should never be reached
        exit(0)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Notification delegate is set in main() before this runs
    }

    // Notification click handler — full implementation in Task 6
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        guard let alertID = userInfo["alert_id"] as? String else {
            completionHandler()
            exit(0)
            return
        }

        // Execute on_click if present
        if let onClick = userInfo["on_click"] as? String, !onClick.isEmpty {
            ShellHelper.execute(command: onClick)
        }

        // Remove state file and notification
        let store = AlertStore()
        store.remove(id: alertID)

        let nm = NotificationManager()
        nm.remove(alertID: alertID)

        // Trigger sketchybar update
        ShellHelper.triggerSketchybar()

        completionHandler()
        exit(0)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

## Verification

1. **Build compiles:**
   ```bash
   swift build
   ```

2. **Test `add` command:**
   ```bash
   .build/debug/MungMung add --title "Test" --message "Hello World" --sound default
   # Should print an alert ID like: 1738000000_a1b2c3d4
   # Should show a macOS notification
   ```

3. **Test `list` command:**
   ```bash
   .build/debug/MungMung list
   # Should show the alert created above in a table
   .build/debug/MungMung list --json
   # Should show JSON array
   ```

4. **Test `count` command:**
   ```bash
   .build/debug/MungMung count
   # Should print: 1
   ```

5. **Test `done` command:**
   ```bash
   .build/debug/MungMung done <id-from-add>
   # Should remove the alert
   .build/debug/MungMung count
   # Should print: 0
   ```

6. **Test `done --run`:**
   ```bash
   .build/debug/MungMung add --title "Test" --message "Click" --on-click "echo clicked > /tmp/mung-test"
   .build/debug/MungMung done <id> --run
   cat /tmp/mung-test
   # Should contain: clicked
   ```

7. **Test `clear`:**
   ```bash
   .build/debug/MungMung add --title "A" --message "1" --group test
   .build/debug/MungMung add --title "B" --message "2" --group test
   .build/debug/MungMung add --title "C" --message "3" --group other
   .build/debug/MungMung clear --group test
   .build/debug/MungMung count
   # Should print: 1 (only the "other" group alert remains)
   ```

8. **Test `version` and `help`:**
   ```bash
   .build/debug/MungMung version
   .build/debug/MungMung help
   ```

## Architecture Context

Commands are the central business logic layer that wires all services together:

```
CLIParser.route()
    │
    ├─── Commands.add()
    │       ├── NotificationManager.requestPermission()
    │       ├── Alert(title:, message:, ...)   ← creates Alert with generated ID
    │       ├── AlertStore.save(alert)          ← writes JSON state file
    │       ├── NotificationManager.send(alert) ← fires macOS notification
    │       ├── ShellHelper.triggerSketchybar() ← sketchybar --trigger mung_alert_change
    │       └── print(alert.id)                 ← outputs ID to stdout
    │
    ├─── Commands.done()
    │       ├── AlertStore.remove(id:)                ← deletes state file, returns alert
    │       ├── ShellHelper.execute(alert.onClick)    ← runs on_click (if --run)
    │       ├── NotificationManager.remove(alertID:)  ← clears notification
    │       └── ShellHelper.triggerSketchybar()
    │
    ├─── Commands.list()
    │       └── AlertStore.list(group:)    ← reads all state files, prints table/JSON
    │
    ├─── Commands.count()
    │       └── AlertStore.count(group:)   ← counts state files, prints number
    │
    ├─── Commands.clear()
    │       ├── AlertStore.clear(group:)             ← removes matching state files
    │       ├── NotificationManager.remove(alertIDs:) ← clears notifications
    │       └── ShellHelper.triggerSketchybar()
    │
    ├─── Commands.version()
    └─── Commands.help()
```

Every state-changing command follows the same pattern:
1. Modify state (AlertStore)
2. Sync notifications (NotificationManager)
3. Trigger sketchybar (ShellHelper)
4. Print output
5. Exit

This ensures state files, Notification Center, and sketchybar are always in sync.

## Test Plan

### Why unit tests aren't practical

`Commands` has two properties that make unit testing infeasible:

1. **Every method calls `exit()`** — `exit(0)` or `exit(1)` terminates the test runner process itself. There is no way to intercept or suppress `exit()` in Swift without process-level isolation.

2. **Hard dependencies on system services** — `Commands` instantiates `NotificationManager` (which calls `UNUserNotificationCenter`) and `ShellHelper` (which spawns real processes) as static properties. These cannot be swapped in tests without protocol-based injection.

Even read-only commands like `list`, `count`, and `help` call `exit(0)` after printing, which would kill the test process.

### What manual/integration verification covers

The Verification section above provides comprehensive CLI-level testing for all 7 commands:
- **add**: Creates state file, sends notification, triggers sketchybar, prints ID
- **done**: Removes state file, optionally runs `on_click` via `--run`, clears notification
- **list**: Human-readable table and `--json` output, `--group` filtering
- **count**: Correct count with and without `--group` filter
- **clear**: Removes matching alerts, `--group` scoping, prints count of removed
- **version**: Reads `CFBundleShortVersionString` from bundle
- **help**: Prints full usage with all subcommands and options

These are tested as end-to-end CLI invocations (`swift run` / `.build/debug/MungMung`), which is the correct level for commands that orchestrate multiple services.

### Future testability

To enable unit testing:

1. **Remove `exit()` from commands** — return an exit code instead and let `main()` call `exit()`:
   ```swift
   static func add(...) -> Int32 { /* ... */ return 0 }
   ```

2. **Inject dependencies** — pass `AlertStore`, `NotificationSending`, and `ShellExecuting` protocols:
   ```swift
   static func add(store: AlertStoring, notifications: NotificationSending, ...) -> Int32
   ```

3. **Capture stdout** — redirect `print()` output to verify CLI output in tests.

This refactoring is deferred — the commands are simple orchestration glue and are well-covered by manual CLI testing.
