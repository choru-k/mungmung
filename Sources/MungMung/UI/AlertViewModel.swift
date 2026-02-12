import AppKit
import Foundation

@MainActor @Observable
final class AlertViewModel {

    var alerts: [Alert] = []

    private let store: AlertStore
    private let notifications: NotificationSending
    private let shell: ShellExecuting
    private let settings: AppSettings

    private var timer: Timer?
    private var notificationObserver: NSObjectProtocol?
    private var pollingObserver: NSObjectProtocol?

    init(
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        settings: AppSettings = AppSettings()
    ) {
        self.store = store
        self.notifications = notifications
        self.shell = shell
        self.settings = settings
    }

    func startPolling() {
        reload()
        startTimer()

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .alertsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }

        pollingObserver = NotificationCenter.default.addObserver(
            forName: .pollingIntervalDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restartTimer()
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
        if let observer = pollingObserver {
            NotificationCenter.default.removeObserver(observer)
            pollingObserver = nil
        }
    }

    func dismiss(_ alert: Alert) {
        store.remove(id: alert.id)
        notifications.remove(alertID: alert.id)
        shell.triggerSketchybar()
        reload()
    }

    func run(_ alert: Alert) {
        if let onClick = alert.onClick, !onClick.isEmpty {
            shell.execute(command: onClick)
        }
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

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: settings.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        startTimer()
    }

    private func reload() {
        alerts = store.list()
    }
}
