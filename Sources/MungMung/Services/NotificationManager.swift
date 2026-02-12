import Foundation
import UserNotifications

/// Wraps UNUserNotificationCenter for sending and managing macOS notifications.
///
/// Each notification carries the alert ID and on_click command in its `userInfo` dictionary,
/// which the AppDelegate reads when the user clicks the notification (see Task 6).
///
/// Notification identifiers match alert IDs, so we can remove specific notifications
/// when an alert is dismissed via CLI (`mung done <id>`) or `mung clear`.
final class NotificationManager: NotificationSending {

    private var center: UNUserNotificationCenter? = {
        // UNUserNotificationCenter.current() crashes if the process has no valid bundle
        // (e.g. when running from .build/debug/). Guard against this.
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }()

    // MARK: - Permission

    /// Request notification authorization. Blocks until the user responds.
    /// Returns true if authorized, false otherwise.
    ///
    /// Called once at first `mung add`. macOS remembers the choice, so subsequent
    /// calls return immediately.
    @discardableResult
    func requestPermission() -> Bool {
        guard let center = center else { return false }

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
        guard let center = center else { return }

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
        center?.removeDeliveredNotifications(withIdentifiers: [alertID])
        center?.removePendingNotificationRequests(withIdentifiers: [alertID])
    }

    /// Remove multiple notifications by alert IDs.
    func remove(alertIDs: [String]) {
        guard !alertIDs.isEmpty else { return }
        center?.removeDeliveredNotifications(withIdentifiers: alertIDs)
        center?.removePendingNotificationRequests(withIdentifiers: alertIDs)
    }
}
