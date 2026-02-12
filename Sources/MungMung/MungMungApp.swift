import AppKit
import SwiftUI
import UserNotifications

// MARK: - Entry Point

@main
enum MungMungEntry {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if !args.isEmpty {
            // CLI mode — parse, route, exit
            let invocation = CLIParser.parse(args)
            CLIParser.route(invocation)
            // CLIParser.route calls exit() internally
        }

        // No args — launch menu bar app
        MungMungApp.main()
    }
}

// MARK: - SwiftUI App

struct MungMungApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var viewModel = AlertViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarLabel(count: viewModel.alerts.count)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Called when the user clicks a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
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

        // Notify the view model to refresh
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)

        completionHandler()
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
