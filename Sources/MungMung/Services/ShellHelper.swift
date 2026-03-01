import Foundation

/// Helper for running shell commands.
///
/// Used by:
/// - Commands.add/done/clear → triggerSketchybar() after state changes
/// - Commands.done (--run) → execute(command:) for on_click
/// - AppDelegate click handler → execute(command:) for on_click
enum ShellHelper {

    struct ActionExecutionContext: Equatable {
        let shellPath: String
        let shellArgumentsPrefix: [String]
        let workingDirectoryPath: String?
    }

    /// Trigger the sketchybar custom event so plugins can update.
    ///
    /// Runs: `sketchybar --trigger mung_alert_change`
    ///
    /// This is a fire-and-forget call. If sketchybar is not running
    /// or the command fails, we only log in debug mode.
    static func triggerSketchybar() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sketchybar", "--trigger", "mung_alert_change"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logActionDebug("failed to trigger sketchybar: \(error.localizedDescription)")
        }
        // Don't wait — fire and forget
    }

    /// Resolve shell/cwd used for on_click command execution.
    ///
    /// Resolution order for shell:
    /// 1) $MUNG_ON_CLICK_SHELL (if executable)
    /// 2) $SHELL (if executable)
    /// 3) /bin/sh
    ///
    /// Working directory:
    /// - $MUNG_ON_CLICK_CWD (if existing directory)
    static func resolveActionExecutionContext(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ActionExecutionContext {
        if let forcedShell = normalized(environment["MUNG_ON_CLICK_SHELL"]),
           FileManager.default.isExecutableFile(atPath: forcedShell) {
            return ActionExecutionContext(
                shellPath: forcedShell,
                shellArgumentsPrefix: loginShellArgs(for: forcedShell),
                workingDirectoryPath: resolvedWorkingDirectory(environment: environment)
            )
        }

        if let userShell = normalized(environment["SHELL"]),
           FileManager.default.isExecutableFile(atPath: userShell) {
            return ActionExecutionContext(
                shellPath: userShell,
                shellArgumentsPrefix: loginShellArgs(for: userShell),
                workingDirectoryPath: resolvedWorkingDirectory(environment: environment)
            )
        }

        return ActionExecutionContext(
            shellPath: "/bin/sh",
            shellArgumentsPrefix: ["-c"],
            workingDirectoryPath: resolvedWorkingDirectory(environment: environment)
        )
    }

    static func isActionDebugEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let raw = normalized(environment["MUNG_DEBUG_ACTIONS"])?.lowercased() else {
            return false
        }

        return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
    }

    /// Execute an on_click command in the resolved shell context.
    ///
    /// The command runs in the background — the app doesn't wait for it to complete.
    static func execute(command: String) {
        let context = resolveActionExecutionContext()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: context.shellPath)
        process.arguments = context.shellArgumentsPrefix + [command]

        if let cwd = context.workingDirectoryPath {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
        }

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logActionDebug("failed to execute on_click command: \(error.localizedDescription)")
        }
        // Don't wait — fire and forget
    }

    private static func resolvedWorkingDirectory(environment: [String: String]) -> String? {
        guard let cwd = normalized(environment["MUNG_ON_CLICK_CWD"]) else { return nil }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: cwd, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        return cwd
    }

    private static func loginShellArgs(for shellPath: String) -> [String] {
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()

        // Use login shell mode when likely supported so PATH/shell init is available.
        if shellName == "bash" || shellName == "zsh" || shellName == "ksh" || shellName == "fish" {
            return ["-lc"]
        }

        return ["-c"]
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private static func logActionDebug(_ message: String) {
        guard isActionDebugEnabled() else { return }
        FileHandle.standardError.write(Data("mung: action: \(message)\n".utf8))
    }
}

/// Instance-based wrapper around ShellHelper for dependency injection.
struct ShellRunner: ShellExecuting {
    func triggerSketchybar() {
        ShellHelper.triggerSketchybar()
    }

    func execute(command: String) {
        ShellHelper.execute(command: command)
    }
}
