import Foundation

/// Helper for running shell commands.
///
/// Used by:
/// - Commands.add/done/clear → triggerSketchybar() after state changes
/// - Commands.done (--run) → execute(command:) for on_click
/// - AppDelegate click handler → execute(command:) for on_click
enum ShellHelper {

    /// Trigger the sketchybar custom event so plugins can update.
    ///
    /// Runs: `sketchybar --trigger mung_alert_change`
    ///
    /// This is a fire-and-forget call. If sketchybar is not running
    /// or the command fails, we silently ignore the error — the CLI
    /// shouldn't fail just because sketchybar isn't active.
    static func triggerSketchybar() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sketchybar", "--trigger", "mung_alert_change"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        // Don't wait — fire and forget
    }

    /// Execute a shell command via `/bin/sh -c "command"`.
    ///
    /// Used for `on_click` actions from alert state files.
    /// The command runs in the background — the app doesn't wait for it to complete.
    ///
    /// - Parameter command: The shell command string to execute
    static func execute(command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        // Don't wait — fire and forget
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
