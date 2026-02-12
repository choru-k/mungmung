import Foundation
import ServiceManagement

@MainActor @Observable
final class AppSettings {

    static let pollingIntervalOptions: [(label: String, value: TimeInterval)] = [
        ("1 second", 1.0),
        ("2 seconds", 2.0),
        ("5 seconds", 5.0),
        ("10 seconds", 10.0),
    ]

    private let defaults: UserDefaults

    var pollingInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: "pollingInterval")
            return value > 0 ? value : 2.0
        }
        set {
            defaults.set(newValue, forKey: "pollingInterval")
            NotificationCenter.default.post(name: .pollingIntervalDidChange, object: nil)
        }
    }

    var soundEnabled: Bool {
        get {
            defaults.object(forKey: "soundEnabled") as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: "soundEnabled")
        }
    }

    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Registration may fail outside a proper app bundle; ignore silently.
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
