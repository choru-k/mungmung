import AppKit
import Foundation

@MainActor @Observable
final class AlertViewModel {

    var alerts: [Alert] = []

    private let store: AlertStore
    private let notifications: NotificationSending
    private let shell: ShellExecuting

    private var timer: Timer?
    private var notificationObserver: NSObjectProtocol?

    init(
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner()
    ) {
        self.store = store
        self.notifications = notifications
        self.shell = shell
    }

    func startPolling() {
        reload()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .alertsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }

    func dismiss(_ alert: Alert) {
        store.remove(id: alert.id)
        notifications.remove(alertID: alert.id)
        shell.triggerSketchybar()
        reload()
    }

    func clearAll() {
        let removed = store.clear()
        let ids = removed.map { $0.id }
        notifications.remove(alertIDs: ids)
        shell.triggerSketchybar()
        reload()
    }

    private func reload() {
        alerts = store.list()
    }
}
