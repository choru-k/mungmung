import Foundation

/// All CLI command implementations.
///
/// Each method returns an Int32 exit code (0 = success, 1 = error).
/// Dependencies are injected via default parameters — existing call sites
/// compile unchanged, but tests can pass mocks.
enum Commands {

    // MARK: - add

    /// Create a new alert, save state, send notification, trigger sketchybar.
    @discardableResult
    static func add(
        title: String,
        message: String,
        onClick: String?,
        icon: String?,
        tags: [String] = [],
        sound: String?,
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        output: (String) -> Void = { print($0) },
        errorOutput: (String) -> Void = { CLIParser.printError($0) }
    ) -> Int32 {
        notifications.requestPermission()

        let alert = Alert(
            title: title,
            message: message,
            onClick: onClick,
            icon: icon,
            tags: tags,
            sound: sound
        )

        do {
            try store.save(alert)
        } catch {
            errorOutput("failed to save alert: \(error.localizedDescription)")
            return 1
        }

        notifications.send(alert: alert)
        shell.triggerSketchybar()

        output(alert.id)
        return 0
    }

    // MARK: - done

    /// Dismiss an alert: remove state file, remove notification, optionally run on_click.
    @discardableResult
    static func done(
        id: String,
        run: Bool,
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        errorOutput: (String) -> Void = { CLIParser.printError($0) }
    ) -> Int32 {
        guard let alert = store.remove(id: id) else {
            errorOutput("alert not found: \(id)")
            return 1
        }

        if run, let onClick = alert.onClick, !onClick.isEmpty {
            shell.execute(command: onClick)
        }

        notifications.remove(alertID: alert.id)
        shell.triggerSketchybar()

        return 0
    }

    // MARK: - list

    /// List pending alerts as human-readable table or JSON.
    @discardableResult
    static func list(
        json: Bool,
        tags: [String] = [],
        store: AlertStore = AlertStore(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let alerts = store.list(tags: tags)

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(alerts),
               let jsonString = String(data: data, encoding: .utf8) {
                output(jsonString)
            } else {
                output("[]")
            }
        } else {
            if alerts.isEmpty {
                output("No pending alerts.")
            } else {
                // Header
                output("\("ID".padding(toLength: 26, withPad: " ", startingAt: 0))\("TAGS".padding(toLength: 14, withPad: " ", startingAt: 0))\("ICON".padding(toLength: 5, withPad: " ", startingAt: 0))\("TITLE".padding(toLength: 20, withPad: " ", startingAt: 0))AGE")

                for alert in alerts {
                    let id = alert.id.padding(toLength: 26, withPad: " ", startingAt: 0)
                    let tagsStr = (alert.tags.isEmpty ? "-" : alert.tags.joined(separator: ","))
                    let tags = String(tagsStr.prefix(14)).padding(toLength: 14, withPad: " ", startingAt: 0)
                    let icon = (alert.icon ?? "-").padding(toLength: 5, withPad: " ", startingAt: 0)
                    let title = String(alert.title.prefix(20)).padding(toLength: 20, withPad: " ", startingAt: 0)
                    output("\(id)\(tags)\(icon)\(title)\(alert.age)")
                }
            }
        }

        return 0
    }

    // MARK: - count

    /// Print the number of pending alerts.
    @discardableResult
    static func count(
        tags: [String] = [],
        store: AlertStore = AlertStore(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        output("\(store.count(tags: tags))")
        return 0
    }

    // MARK: - clear

    /// Remove all alerts (or all matching given tags).
    @discardableResult
    static func clear(
        tags: [String] = [],
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let removed = store.clear(tags: tags)
        let ids = removed.map { $0.id }

        notifications.remove(alertIDs: ids)
        shell.triggerSketchybar()

        output("Cleared \(removed.count) alert\(removed.count == 1 ? "" : "s").")
        return 0
    }

    // MARK: - version

    /// Print version string.
    @discardableResult
    static func version(
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
        output("mung \(version)")
        return 0
    }

    // MARK: - help

    /// Print usage information.
    @discardableResult
    static func help(
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        output("""
        Usage: mung <command> [options]

        Commands:
          add      Create alert and send notification
                   --title "..."       Alert title (required)
                   --message "..."     Alert message (required)
                   --on-click "cmd"    Command to run on notification click
                   --icon "..."        Icon (emoji, SF Symbol name, or image path)
                   --tag "name"        Tag for filtering (repeatable)
                   --sound "default"   Notification sound

          done     Dismiss alert by ID
                   <id>                Alert ID (required)
                   --run               Execute on_click command

          list     List pending alerts
                   --json              Output as JSON
                   --tag "name"        Filter by tag (repeatable, OR match)

          count    Print number of pending alerts
                   --tag "name"        Filter by tag (repeatable, OR match)

          clear    Dismiss all alerts
                   --tag "name"        Clear only alerts with this tag (repeatable, OR match)

          version  Print version
          help     Show this help

        State directory: $MUNG_DIR (default: ~/.local/share/mung)
        """)
        return 0
    }
}
