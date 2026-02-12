import AppKit
import UserNotifications

@main
struct MungMungApp {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty {
            // No CLI args — this could be:
            // 1. User ran `mung` with no args → show help
            // 2. macOS relaunched the app after a notification click → handle click
            //
            // We set up NSApplication and UNUserNotificationCenter only in this path,
            // because UNUserNotificationCenter requires a valid app bundle (crashes
            // otherwise when the binary is run from .build/debug/).
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate

            // Set notification delegate BEFORE the run loop processes any pending notifications
            UNUserNotificationCenter.current().delegate = delegate

            app.finishLaunching()

            let deadline = Date().addingTimeInterval(2.0)
            while Date() < deadline && !delegate.handledNotification {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
            }

            if !delegate.handledNotification {
                _ = Commands.help()
            }
            exit(0)
        }

        // Normal CLI invocation — parse and route
        let invocation = CLIParser.parse(args)
        CLIParser.route(invocation)
        exit(0)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Set to true when a notification click is handled.
    /// Used by main() to distinguish between "no args" and "notification relaunch".
    var handledNotification = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Notification delegate is already set in main()
    }

    /// Called when the user clicks a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handledNotification = true

        let userInfo = response.notification.request.content.userInfo

        guard let alertID = userInfo["alert_id"] as? String else {
            completionHandler()
            return
        }

        // Execute on_click command if user clicked the notification body
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let onClick = userInfo["on_click"] as? String, !onClick.isEmpty {
                ShellHelper.execute(command: onClick)
            }
        }

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
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
