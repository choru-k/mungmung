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
        source: String? = nil,
        session: String? = nil,
        kind: String? = nil,
        dedupeKey: String? = nil,
        sound: String?,
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        output: (String) -> Void = { print($0) },
        errorOutput: (String) -> Void = { CLIParser.printError($0) }
    ) -> Int32 {
        notifications.requestPermission()

        let normalizedSource = normalized(source)
        let normalizedSession = normalized(session)
        let normalizedKind = normalized(kind)
        let normalizedDedupeKey = normalized(dedupeKey)

        logLifecycle(
            "add source=\(normalizedSource ?? "-") session=\(normalizedSession ?? "-") kind=\(normalizedKind ?? "-") dedupe=\(normalizedDedupeKey ?? "-") tags=\(tags.count)"
        )

        if let dedupe = normalizedDedupeKey {
            let existing = store.list(
                sessions: normalizedSession.map { [$0] } ?? [],
                dedupeKeys: [dedupe]
            )

            if !existing.isEmpty {
                _ = store.clear(
                    sessions: normalizedSession.map { [$0] } ?? [],
                    dedupeKeys: [dedupe]
                )
                notifications.remove(alertIDs: existing.map { $0.id })
                logLifecycle("add dedupe_replaced count=\(existing.count) key=\(dedupe)")
            }
        }

        let alert = Alert(
            title: title,
            message: message,
            onClick: onClick,
            icon: icon,
            tags: tags,
            source: normalizedSource,
            session: normalizedSession,
            kind: normalizedKind,
            dedupeKey: normalizedDedupeKey,
            sound: sound
        )

        do {
            try store.save(alert)
        } catch {
            logLifecycle("add failed_save error=\(error.localizedDescription)")
            errorOutput("failed to save alert: \(error.localizedDescription)")
            return 1
        }

        notifications.send(alert: alert)
        shell.triggerSketchybar()

        logLifecycle("add saved id=\(alert.id)")
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
            logLifecycle("done missing id=\(id)")
            errorOutput("alert not found: \(id)")
            return 1
        }

        if run, let onClick = alert.onClick, !onClick.isEmpty {
            shell.execute(command: onClick)
            logLifecycle("done run_action id=\(id)")
        }

        notifications.remove(alertID: alert.id)
        shell.triggerSketchybar()

        logLifecycle("done removed id=\(id)")
        return 0
    }

    // MARK: - list

    /// List pending alerts as human-readable table or JSON.
    @discardableResult
    static func list(
        json: Bool,
        tags: [String] = [],
        sources: [String] = [],
        sessions: [String] = [],
        kinds: [String] = [],
        dedupeKeys: [String] = [],
        store: AlertStore = AlertStore(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let alerts = store.list(
            tags: tags,
            sources: sources,
            sessions: sessions,
            kinds: kinds,
            dedupeKeys: dedupeKeys
        )

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
        sources: [String] = [],
        sessions: [String] = [],
        kinds: [String] = [],
        dedupeKeys: [String] = [],
        store: AlertStore = AlertStore(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        output("\(store.count(tags: tags, sources: sources, sessions: sessions, kinds: kinds, dedupeKeys: dedupeKeys))")
        return 0
    }

    // MARK: - clear

    /// Remove all alerts (or all matching given tags).
    @discardableResult
    static func clear(
        tags: [String] = [],
        sources: [String] = [],
        sessions: [String] = [],
        kinds: [String] = [],
        dedupeKeys: [String] = [],
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let removed = store.clear(
            tags: tags,
            sources: sources,
            sessions: sessions,
            kinds: kinds,
            dedupeKeys: dedupeKeys
        )
        let ids = removed.map { $0.id }

        notifications.remove(alertIDs: ids)
        shell.triggerSketchybar()

        logLifecycle(
            "clear removed=\(removed.count) tags=\(tags.count) sources=\(sources.count) sessions=\(sessions.count) kinds=\(kinds.count) dedupe=\(dedupeKeys.count)"
        )
        output("Cleared \(removed.count) alert\(removed.count == 1 ? "" : "s").")
        return 0
    }

    // MARK: - doctor

    /// Print runtime diagnostics to help troubleshoot integration/runtime issues.
    @discardableResult
    static func doctor(
        json: Bool,
        store: AlertStore = AlertStore(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let executablePath = ProcessInfo.processInfo.arguments.first ?? ""
        let resolvedPath = URL(fileURLWithPath: executablePath)
            .resolvingSymlinksInPath()
            .path

        var isDirectory = ObjCBool(false)
        let alertsDirExists = FileManager.default.fileExists(
            atPath: store.alertsDir.path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue

        let actionContext = ShellHelper.resolveActionExecutionContext()

        let report = DoctorReport(
            timestamp: Date(),
            version: resolvedVersion(),
            executablePath: executablePath,
            resolvedExecutablePath: resolvedPath,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            notificationsAvailable: NotificationManager.canUseNotificationCenter(),
            bundledExecutable: NotificationManager.isBundledExecutable(resolvedPath: resolvedPath),
            state: DoctorStateReport(
                mungDir: store.baseDir.path,
                alertsDir: store.alertsDir.path,
                alertsDirectoryExists: alertsDirExists,
                alertCount: store.count()
            ),
            actionExecution: DoctorActionExecutionReport(
                shellPath: actionContext.shellPath,
                shellArgumentsPrefix: actionContext.shellArgumentsPrefix,
                workingDirectory: actionContext.workingDirectoryPath,
                debugActionsEnabled: ShellHelper.isActionDebugEnabled(),
                debugLifecycleEnabled: isLifecycleDebugEnabled()
            )
        )

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            if let data = try? encoder.encode(report),
               let jsonText = String(data: data, encoding: .utf8) {
                output(jsonText)
            } else {
                output("{}")
            }

            return 0
        }

        output("mung doctor")
        output("version: \(report.version)")
        output("bundle_id: \(report.bundleIdentifier ?? "-")")
        output("executable: \(report.executablePath)")
        output("resolved_executable: \(report.resolvedExecutablePath)")
        output("bundled_executable: \(report.bundledExecutable ? "yes" : "no")")
        output("notifications_available: \(report.notificationsAvailable ? "yes" : "no")")
        output("mung_dir: \(report.state.mungDir)")
        output("alerts_dir: \(report.state.alertsDir)")
        output("alerts_dir_exists: \(report.state.alertsDirectoryExists ? "yes" : "no")")
        output("alert_count: \(report.state.alertCount)")
        output("on_click_shell: \(report.actionExecution.shellPath)")
        output("on_click_shell_args: \(report.actionExecution.shellArgumentsPrefix.joined(separator: " "))")
        output("on_click_cwd: \(report.actionExecution.workingDirectory ?? "-")")
        output("debug_actions: \(report.actionExecution.debugActionsEnabled ? "on" : "off")")
        output("debug_lifecycle: \(report.actionExecution.debugLifecycleEnabled ? "on" : "off")")

        return 0
    }

    // MARK: - version

    /// Print version string.
    @discardableResult
    static func version(
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        output("mung \(resolvedVersion())")
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
                   --tag "name"        Optional custom label (repeatable)
                   --source "name"     Alert source (e.g. pi-agent, claude)
                   --session "id"      Alert session ID
                   --kind "name"       Alert kind (e.g. update, action)
                   --dedupe-key "key"  Replace previous matching alert before add
                   --sound "default"   Notification sound

          done     Dismiss alert by ID
                   <id>                Alert ID (required)
                   --run               Execute on_click command

          list     List pending alerts
                   --json              Output as JSON
                   --tag "name"        Filter by tag (repeatable, OR match)
                   --source "name"     Filter by source (repeatable, OR match)
                   --session "id"      Filter by session (repeatable, OR match)
                   --kind "name"       Filter by kind (repeatable, OR match)
                   --dedupe-key "key"  Filter by dedupe key (repeatable, OR match)

          count    Print number of pending alerts
                   --tag "name"        Filter by tag (repeatable, OR match)
                   --source "name"     Filter by source (repeatable, OR match)
                   --session "id"      Filter by session (repeatable, OR match)
                   --kind "name"       Filter by kind (repeatable, OR match)
                   --dedupe-key "key"  Filter by dedupe key (repeatable, OR match)

          clear    Dismiss matching alerts
                   --tag "name"        Filter by tag (repeatable, OR match)
                   --source "name"     Filter by source (repeatable, OR match)
                   --session "id"      Filter by session (repeatable, OR match)
                   --kind "name"       Filter by kind (repeatable, OR match)
                   --dedupe-key "key"  Filter by dedupe key (repeatable, OR match)

          doctor   Print runtime diagnostics
                   --json              Output diagnostics as JSON

          version  Print version
          help     Show this help

        State directory: $MUNG_DIR (default: ~/.local/share/mung)

        Action execution environment:
          MUNG_ON_CLICK_SHELL   Preferred shell for on_click execution
          MUNG_ON_CLICK_CWD     Working directory for on_click execution
          MUNG_DEBUG_ACTIONS    Set to 1/true/yes/on to log action failures
          MUNG_DEBUG_LIFECYCLE  Set to 1/true/yes/on to log add/done/clear lifecycle
        """)
        return 0
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func resolvedVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
    }

    private static func isLifecycleDebugEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let raw = normalized(environment["MUNG_DEBUG_LIFECYCLE"])?.lowercased() else {
            return false
        }

        return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
    }

    private static func logLifecycle(_ message: String) {
        guard isLifecycleDebugEnabled() else { return }
        FileHandle.standardError.write(Data("mung: lifecycle: \(message)\n".utf8))
    }

    private struct DoctorReport: Codable {
        let timestamp: Date
        let version: String
        let executablePath: String
        let resolvedExecutablePath: String
        let bundleIdentifier: String?
        let notificationsAvailable: Bool
        let bundledExecutable: Bool
        let state: DoctorStateReport
        let actionExecution: DoctorActionExecutionReport
    }

    private struct DoctorStateReport: Codable {
        let mungDir: String
        let alertsDir: String
        let alertsDirectoryExists: Bool
        let alertCount: Int
    }

    private struct DoctorActionExecutionReport: Codable {
        let shellPath: String
        let shellArgumentsPrefix: [String]
        let workingDirectory: String?
        let debugActionsEnabled: Bool
        let debugLifecycleEnabled: Bool
    }
}
