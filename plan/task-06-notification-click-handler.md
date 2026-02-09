# Task 6: Notification Click Handler

## Background

When a user clicks a mungmung notification in macOS Notification Center, macOS relaunches the app (since it exited after sending the notification). The `AppDelegate`, as `UNUserNotificationCenterDelegate`, receives the click event via `didReceive(_:withCompletionHandler:)`.

The click handler:
1. Extracts `alert_id` and `on_click` from the notification's `userInfo`
2. Executes the `on_click` shell command (if present)
3. Removes the alert state file
4. Removes the notification from Notification Center
5. Triggers sketchybar update
6. Exits

This is already mostly implemented as part of Task 5's `MungMungApp.swift` update. This task focuses on the details and edge cases of the notification click handling flow.

## Dependencies

- **Task 2** (Alert Model & State Store) — `AlertStore` for removing state files
- **Task 4** (Notification Manager) — `NotificationManager` for removing notifications
- **Task 7** (Shell Helper) — `ShellHelper` for executing `on_click` and triggering sketchybar

## Files to Modify

| File | Action | Purpose |
|------|--------|---------|
| `Sources/MungMung/MungMungApp.swift` | Modify | Complete notification click handler in AppDelegate |

## Implementation

### `Sources/MungMung/MungMungApp.swift` — AppDelegate Notification Handling

The key section is the `didReceive` delegate method and the no-args launch detection. Here's the complete, final version of the relevant parts:

```swift
import AppKit
import UserNotifications

@main
struct MungMungApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        // Set notification delegate BEFORE the run loop processes any pending notifications
        UNUserNotificationCenter.current().delegate = delegate

        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty {
            // No CLI args — this could be:
            // 1. User ran `mung` with no args → show help
            // 2. macOS relaunched the app after a notification click → handle click
            //
            // We run the event loop briefly. If macOS has a pending notification
            // response, it will call didReceive() on the delegate, which handles
            // the click and exits. If no callback comes (timeout), show help.
            //
            // The delegate sets `handledNotification = true` if it processes a click,
            // so we can distinguish between the two cases.
            app.finishLaunching()

            let deadline = Date().addingTimeInterval(2.0)
            while Date() < deadline && !delegate.handledNotification {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
            }

            if !delegate.handledNotification {
                Commands.help()
            }
            exit(0)
        }

        // Normal CLI invocation — parse and route
        let invocation = CLIParser.parse(args)
        CLIParser.route(invocation)
        exit(0)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Set to true when a notification click is handled.
    /// Used by main() to distinguish between "no args" and "notification relaunch".
    var handledNotification = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Notification delegate is already set in main()
    }

    /// Called when the user clicks a notification.
    ///
    /// macOS delivers the click response here. We:
    /// 1. Extract alert_id and on_click from userInfo
    /// 2. Execute on_click command (if present) in background
    /// 3. Remove the alert state file
    /// 4. Remove the notification from Notification Center
    /// 5. Trigger sketchybar update
    /// 6. Exit
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handledNotification = true

        let userInfo = response.notification.request.content.userInfo

        guard let alertID = userInfo["alert_id"] as? String else {
            // Notification without our metadata — nothing to do
            completionHandler()
            exit(0)
            return
        }

        // Execute on_click command if present
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // User clicked the notification body (default action)
            if let onClick = userInfo["on_click"] as? String, !onClick.isEmpty {
                ShellHelper.execute(command: onClick)
            }
        }
        // If actionIdentifier is UNNotificationDismissActionIdentifier, the user
        // dismissed the notification — we still clean up state but don't run on_click.

        // Remove state file
        let store = AlertStore()
        store.remove(id: alertID)

        // Remove notification from Notification Center
        let nm = NotificationManager()
        nm.remove(alertID: alertID)

        // Trigger sketchybar update
        ShellHelper.triggerSketchybar()

        completionHandler()
        exit(0)
    }

    /// Show notification banner even when the app is in the foreground.
    ///
    /// This matters for the brief moment during `mung add` when the app is running
    /// and the notification is delivered — we still want the banner to appear.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

### Edge Cases Handled

1. **No-args launch vs notification relaunch**: The `handledNotification` flag distinguishes between the user running `mung` with no arguments (→ show help) and macOS relaunching the app for a notification click (→ handle click, exit).

2. **Notification dismissed (not clicked)**: If `actionIdentifier == UNNotificationDismissActionIdentifier`, we still clean up the state file but don't execute `on_click`. The user can later run `mung done <id> --run` to execute the action manually.

3. **Missing userInfo**: If a notification somehow doesn't have `alert_id` in `userInfo`, we just exit cleanly.

4. **Already-removed state file**: If `store.remove(id:)` returns nil (state file already gone, e.g., user ran `mung done` before clicking the notification), we still proceed to remove the notification and exit — no error.

5. **on_click execution is fire-and-forget**: `ShellHelper.execute()` runs the command in background. The app exits immediately; it doesn't wait for the command to complete.

## Verification

1. **Build compiles:**
   ```bash
   swift build
   ```

2. **Test notification click flow:**
   ```bash
   # Create an alert with an on_click action
   ID=$(.build/debug/MungMung add --title "Click Me" --message "Testing click handler" \
     --on-click "echo clicked > /tmp/mung-click-test" --sound default)
   echo "Alert ID: $ID"

   # Click the notification in macOS Notification Center
   # (manual step — click the banner or find it in NC)

   # After clicking, verify:
   cat /tmp/mung-click-test
   # Should contain: clicked

   .build/debug/MungMung count
   # Should be 0 (state file removed by click handler)
   ```

3. **Test notification dismiss (swipe away):**
   ```bash
   ID=$(.build/debug/MungMung add --title "Dismiss Me" --message "Swipe this away")
   # Swipe/dismiss the notification (don't click it)
   # State file should still exist:
   .build/debug/MungMung count
   # Should be 1 (dismissing a banner doesn't trigger the app)
   # Clean up:
   .build/debug/MungMung done $ID
   ```

4. **Test no-args launch:**
   ```bash
   .build/debug/MungMung
   # Should print help (after a brief ~2s delay for notification check)
   ```

## Architecture Context

The notification click handling is the second mode of operation for the app (the first being CLI mode):

```
macOS Notification Center
         │
         │  User clicks notification
         │
         ▼
macOS relaunches MungMung.app
         │
         │  CommandLine.arguments = ["/path/to/MungMung"]  (no subcommand)
         │
         ▼
main() sees no args → runs event loop
         │
         │  macOS delivers notification response
         │
         ▼
AppDelegate.didReceive(response:)
         │
         ├── response.notification.request.content.userInfo
         │   ├── "alert_id": "1738000000_a1b2c3d4"
         │   └── "on_click": "aerospace workspace Terminal"
         │
         ├── ShellHelper.execute("aerospace workspace Terminal")
         ├── AlertStore.remove(id: "1738000000_a1b2c3d4")
         ├── NotificationManager.remove(alertID: "1738000000_a1b2c3d4")
         ├── ShellHelper.triggerSketchybar()
         └── exit(0)
```

The two modes (CLI and notification click) share the same services:
- `AlertStore` for state file operations
- `NotificationManager` for notification management
- `ShellHelper` for shell command execution and sketchybar triggers

This keeps the codebase simple — the same removal logic in `mung done` and the notification click handler.
