import AppKit
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
        guard NotificationManager.canUseNotificationCenter() else { return nil }
        return UNUserNotificationCenter.current()
    }()

    /// Returns `true` when the resolved executable path is inside a `.app` bundle.
    static func isBundledExecutable(resolvedPath: String) -> Bool {
        resolvedPath.contains(".app/Contents/MacOS/")
    }

    /// Determines whether notification APIs are expected to work in this process.
    ///
    /// Notification center is available when:
    /// - The process has a bundle identifier, OR
    /// - The executable resolves inside an app bundle path.
    static func canUseNotificationCenter(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        executablePath: String = ProcessInfo.processInfo.arguments[0]
    ) -> Bool {
        if bundleIdentifier != nil {
            return true
        }

        let resolvedPath = URL(fileURLWithPath: executablePath)
            .resolvingSymlinksInPath()
            .path
        return isBundledExecutable(resolvedPath: resolvedPath)
    }

    // MARK: - Permission

    /// Request notification authorization. Blocks until the user responds.
    /// Returns true if authorized, false otherwise.
    ///
    /// Called once at first `mung add`. macOS remembers the choice, so subsequent
    /// calls return immediately.
    @discardableResult
    func requestPermission() -> Bool {
        guard let center = center else { return false }

        final class PermissionResult: @unchecked Sendable {
            var authorized = false
        }

        let result = PermissionResult()
        let semaphore = DispatchSemaphore(value: 0)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                FileHandle.standardError.write(
                    Data("mung: notification permission error: \(error.localizedDescription)\n".utf8)
                )
            }
            result.authorized = granted
            semaphore.signal()
        }

        semaphore.wait()
        return result.authorized
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

        // Sound (respect global setting)
        let soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        if soundEnabled, let sound = alert.sound {
            if sound == "default" {
                content.sound = .default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            }
        }

        // Thread identifier for grouping (uses first tag)
        if let firstTag = alert.tags.first {
            content.threadIdentifier = firstTag
        }

        // Icon attachment (renders icon to temp PNG for notification thumbnail)
        if let icon = alert.icon, !icon.isEmpty,
           let image = IconRenderer.renderToImage(icon, pointSize: 64),
           let tempURL = IconRenderer.writeTempPNG(image) {
            defer { try? FileManager.default.removeItem(at: tempURL) }
            if let attachment = try? UNNotificationAttachment(
                identifier: "icon", url: tempURL, options: nil
            ) {
                content.attachments = [attachment]
            }
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
