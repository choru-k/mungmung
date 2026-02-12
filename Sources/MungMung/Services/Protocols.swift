import Foundation

/// Abstracts notification operations for dependency injection in Commands.
protocol NotificationSending {
    @discardableResult func requestPermission() -> Bool
    func send(alert: Alert)
    func remove(alertID: String)
    func remove(alertIDs: [String])
}

/// Abstracts shell execution for dependency injection in Commands.
protocol ShellExecuting {
    func triggerSketchybar()
    func execute(command: String)
}
