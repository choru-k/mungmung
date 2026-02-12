import Foundation
@testable import MungMung

// MARK: - MockNotificationManager

/// Records all notification operations for test assertions.
final class MockNotificationManager: NotificationSending {
    var permissionRequested = false
    var permissionResult = true
    var sentAlerts: [Alert] = []
    var removedAlertIDs: [String] = []
    var removedAlertIDsBatch: [[String]] = []

    @discardableResult
    func requestPermission() -> Bool {
        permissionRequested = true
        return permissionResult
    }

    func send(alert: Alert) {
        sentAlerts.append(alert)
    }

    func remove(alertID: String) {
        removedAlertIDs.append(alertID)
    }

    func remove(alertIDs: [String]) {
        removedAlertIDsBatch.append(alertIDs)
    }
}

// MARK: - MockShellRunner

/// Records all shell operations for test assertions.
final class MockShellRunner: ShellExecuting {
    var triggerSketchybarCount = 0
    var executedCommands: [String] = []

    func triggerSketchybar() {
        triggerSketchybarCount += 1
    }

    func execute(command: String) {
        executedCommands.append(command)
    }
}

// MARK: - OutputCapture

/// Collects output strings via a closure for testing Commands output.
final class OutputCapture {
    var lines: [String] = []

    var capture: (String) -> Void {
        return { [weak self] text in
            self?.lines.append(text)
        }
    }

    /// All captured output joined with newlines.
    var text: String {
        lines.joined(separator: "\n")
    }
}
