import AppKit
import UserNotifications

// MARK: - App Entry Point

@main
struct MungMungApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        // Check if launched from notification click
        // (expanded in Task 6)

        // Parse CLI arguments and dispatch
        // (expanded in Task 5)
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty {
            Commands.help()
            exit(0)
        }

        // Placeholder — will be replaced by CLIParser.route() in Task 5
        print("mungmung: not yet implemented")
        exit(0)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // Notification click handler (expanded in Task 6)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Placeholder — expanded in Task 6
        completionHandler()
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// Placeholder namespace for commands — replaced in Task 5
enum Commands {
    static func help() {
        print("""
        Usage: mung <command> [options]

        Commands:
          add      Create alert and send notification
          done     Dismiss alert by ID
          list     List pending alerts
          count    Print alert count
          clear    Dismiss all alerts
          version  Print version
          help     Show this help
        """)
    }
}
