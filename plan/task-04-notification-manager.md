# Task 4: Notification Manager

## Background

mungmung sends native macOS notifications via `UNUserNotificationCenter`. This is the key differentiator from terminal-notifier — full control over notification content, reliable click handling through the delegate pattern, and the ability to programmatically remove delivered notifications.

The `NotificationManager` wraps `UNUserNotificationCenter` and handles:
1. Requesting notification permission
2. Sending a notification with title, message, icon, sound, and `userInfo` (carrying the alert ID and `on_click` command)
3. Removing pending/delivered notifications by alert ID

## Dependencies

- **Task 1** (Project Setup) — Package.swift and directory structure must exist

## Files to Create

| File | Purpose |
|------|---------|
| `Sources/MungMung/Services/NotificationManager.swift` | UNUserNotificationCenter wrapper |

## Implementation

### `Sources/MungMung/Services/NotificationManager.swift`

```swift
import Foundation
import UserNotifications

/// Wraps UNUserNotificationCenter for sending and managing macOS notifications.
///
/// Each notification carries the alert ID and on_click command in its `userInfo` dictionary,
/// which the AppDelegate reads when the user clicks the notification (see Task 6).
///
/// Notification identifiers match alert IDs, so we can remove specific notifications
/// when an alert is dismissed via CLI (`mung done <id>`) or `mung clear`.
final class NotificationManager {

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    /// Request notification authorization. Blocks until the user responds.
    /// Returns true if authorized, false otherwise.
    ///
    /// Called once at first `mung add`. macOS remembers the choice, so subsequent
    /// calls return immediately.
    @discardableResult
    func requestPermission() -> Bool {
        var authorized = false
        let semaphore = DispatchSemaphore(value: 0)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                FileHandle.standardError.write(
                    Data("mung: notification permission error: \(error.localizedDescription)\n".utf8)
                )
            }
            authorized = granted
            semaphore.signal()
        }

        semaphore.wait()
        return authorized
    }

    // MARK: - Send Notification

    /// Send a macOS notification for the given alert.
    ///
    /// The notification's `userInfo` carries:
    /// - `"alert_id"`: the alert ID (for removal on click)
    /// - `"on_click"`: the command to execute on click (optional)
    ///
    /// The notification identifier is set to the alert ID so we can remove it later.
    func send(alert: Alert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message

        // Sound
        if let sound = alert.sound {
            if sound == "default" {
                content.sound = .default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            }
        }

        // Thread identifier for grouping (maps to alert group)
        if let group = alert.group {
            content.threadIdentifier = group
        }

        // userInfo carries alert metadata for click handling
        var userInfo: [String: String] = ["alert_id": alert.id]
        if let onClick = alert.onClick {
            userInfo["on_click"] = onClick
        }
        content.userInfo = userInfo

        // Use alert ID as notification identifier for later removal
        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: nil  // deliver immediately
        )

        let semaphore = DispatchSemaphore(value: 0)

        center.add(request) { error in
            if let error = error {
                FileHandle.standardError.write(
                    Data("mung: notification error: \(error.localizedDescription)\n".utf8)
                )
            }
            semaphore.signal()
        }

        semaphore.wait()
    }

    // MARK: - Remove Notifications

    /// Remove a delivered notification and any pending requests by alert ID.
    ///
    /// Called by:
    /// - `mung done <id>` — removes notification when alert is dismissed via CLI
    /// - Notification click handler — removes notification after handling the click
    /// - `mung clear` — removes all notifications for cleared alerts
    func remove(alertID: String) {
        center.removeDeliveredNotifications(withIdentifiers: [alertID])
        center.removePendingNotificationRequests(withIdentifiers: [alertID])
    }

    /// Remove multiple notifications by alert IDs.
    func remove(alertIDs: [String]) {
        guard !alertIDs.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: alertIDs)
        center.removePendingNotificationRequests(withIdentifiers: alertIDs)
    }
}
```

## Verification

1. **Build compiles:**
   ```bash
   swift build
   ```

2. **Manual test — send a notification:**
   Add temporary test code in `main()`:
   ```swift
   let nm = NotificationManager()
   let authorized = nm.requestPermission()
   print("Notification permission: \(authorized)")

   if authorized {
       let alert = Alert(title: "Test", message: "MungMung works!", sound: "default")
       nm.send(alert: alert)
       print("Notification sent for alert: \(alert.id)")

       // Wait a moment for the notification to appear
       sleep(3)

       // Then remove it
       nm.remove(alertID: alert.id)
       print("Notification removed")
   }
   ```
   Run `swift run MungMung` — should show a macOS notification, then remove it after 3 seconds.

3. **First run permission prompt:**
   On first run, macOS should show "MungMung would like to send you notifications" — click Allow.

4. **Verify userInfo:**
   Create an alert with `onClick` set:
   ```swift
   let alert = Alert(title: "Test", message: "Click me", onClick: "open https://example.com")
   nm.send(alert: alert)
   ```
   The notification's `userInfo` should contain `alert_id` and `on_click` keys (verified in Task 6 when the click handler reads them).

## Architecture Context

The NotificationManager is used by three components:

```
┌─────────────┐     send(alert:)     ┌─────────────────────┐
│ Commands.add ├─────────────────────>│ NotificationManager  │
│   (Task 5)  │                      │                     │
├─────────────┤     remove(alertID:)  │  UNUserNotification │
│ Commands.done├─────────────────────>│  Center             │
│   (Task 5)  │                      │                     │
├─────────────┤     remove(alertIDs:) │  - requestPermission│
│Commands.clear├─────────────────────>│  - send             │
│   (Task 5)  │                      │  - remove           │
├─────────────┤                      └─────────────────────┘
│ AppDelegate  │     remove(alertID:)          │
│ click handler├──────────────────────────────►│
│   (Task 6)  │
└─────────────┘
```

**Notification lifecycle:**
1. `mung add` → `NotificationManager.send()` → macOS shows notification
2. User sees notification in Notification Center
3. User clicks notification → macOS relaunches app → `AppDelegate.didReceive` → reads `userInfo` → executes `on_click` → calls `mung done <id>` internally
4. `mung done` → `NotificationManager.remove()` → notification disappears from Notification Center

**Key design decisions:**
- Notification `identifier` = alert `id` — this is how we match notifications to state files
- `userInfo` carries `alert_id` and `on_click` — the click handler in Task 6 reads these
- `trigger: nil` means deliver immediately (no scheduling)
- We use semaphores to make async UNUserNotificationCenter calls synchronous (the CLI is a synchronous tool)
- Permission is requested once; macOS remembers the user's choice

## Test Plan

### Why unit tests aren't practical

`NotificationManager` is a thin wrapper around `UNUserNotificationCenter`, which is a system framework singleton that:
- Requires a running app with a valid bundle identifier to function
- Pops real macOS permission dialogs (`requestAuthorization`)
- Delivers real notifications to Notification Center
- Cannot be instantiated or mocked without protocol extraction

Every method (`requestPermission`, `send`, `remove`) calls `UNUserNotificationCenter.current()` directly. There is no seam for injecting a test double.

### What manual/integration verification covers

The Verification section above covers the full surface:
- **Permission flow**: First-run dialog appears, subsequent calls return immediately
- **Send**: Notification banner appears with correct title, body, and sound
- **userInfo roundtrip**: `alert_id` and `on_click` are carried through to the click handler (verified end-to-end in Task 6)
- **Remove**: Notification disappears from Notification Center after `remove(alertID:)`
- **Error resilience**: Errors are logged to stderr, not thrown — the CLI doesn't crash on notification failures

### Future testability

To enable unit testing, `NotificationManager` could be refactored behind a protocol:

```swift
protocol NotificationSending {
    @discardableResult func requestPermission() -> Bool
    func send(alert: Alert)
    func remove(alertID: String)
    func remove(alertIDs: [String])
}
```

`Commands` would depend on `NotificationSending` instead of the concrete class, allowing a `MockNotificationManager` in tests. This refactoring is not warranted now — the class is stable and fully verified manually.
