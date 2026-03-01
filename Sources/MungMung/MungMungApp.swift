import AppKit
import SwiftUI
import UserNotifications

// MARK: - Entry Point

@main
enum MungMungEntry {
    /// Determines whether the given arguments indicate CLI mode.
    /// Returns `true` for known subcommands (plain words) and CLI flags (--help, -h).
    /// Returns `false` for empty args or macOS launch-service flags (-NSxxx, -Apple).
    static func isCLIMode(_ args: [String]) -> Bool {
        guard let first = args.first else { return false }
        return !first.hasPrefix("-") || first == "--help" || first == "-h"
    }

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if isCLIMode(args) {
            let invocation = CLIParser.parse(args)
            CLIParser.route(invocation)
            // CLIParser.route calls exit() internally
        }

        // No CLI subcommand — launch menu bar app
        MungMungApp.main()
    }
}

// MARK: - SwiftUI App

struct MungMungApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var settings: AppSettings
    @State private var viewModel: AlertViewModel

    init() {
        let s = AppSettings()
        _settings = State(initialValue: s)
        _viewModel = State(initialValue: AlertViewModel(settings: s))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarLabel(count: viewModel.alerts.count)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
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

        let shouldRunOnClick = response.actionIdentifier == UNNotificationDefaultActionIdentifier

        _ = Commands.done(
            id: alertID,
            run: shouldRunOnClick,
            errorOutput: { _ in }
        )

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
        let soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        completionHandler(soundEnabled ? [.banner, .sound] : [.banner])
    }
}
