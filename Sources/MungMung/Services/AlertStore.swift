import Foundation

/// Manages alert state files on disk.
///
/// State directory: `$MUNG_DIR/alerts/` (default: `~/.local/share/mung/alerts/`)
/// Each alert is a separate JSON file: `<id>.json`
///
/// This class handles:
/// - Creating the state directory if it doesn't exist
/// - Writing new alert files
/// - Reading individual alerts by ID
/// - Listing all alerts (optionally filtered by group)
/// - Removing alert files
/// - Counting alerts
final class AlertStore {

    /// Root state directory. Resolved from $MUNG_DIR or default.
    let baseDir: URL

    /// Alerts subdirectory: `$MUNG_DIR/alerts/`
    var alertsDir: URL { baseDir.appendingPathComponent("alerts") }

    /// JSON encoder configured for alert files
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// JSON decoder configured for alert files
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        if let envDir = ProcessInfo.processInfo.environment["MUNG_DIR"] {
            self.baseDir = URL(fileURLWithPath: envDir)
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.baseDir = home
                .appendingPathComponent(".local/share/mung")
        }
    }

    // MARK: - Directory Management

    /// Ensure the alerts directory exists. Creates it (and parents) if needed.
    func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: alertsDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - CRUD Operations

    /// Save an alert to disk as `alerts/<id>.json`.
    /// Creates the directory if it doesn't exist.
    @discardableResult
    func save(_ alert: Alert) throws -> URL {
        try ensureDirectory()
        let fileURL = alertsDir.appendingPathComponent("\(alert.id).json")
        let data = try encoder.encode(alert)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Load a single alert by ID.
    /// Returns nil if the file doesn't exist.
    func load(id: String) -> Alert? {
        let fileURL = alertsDir.appendingPathComponent("\(id).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(Alert.self, from: data)
    }

    /// Remove an alert's state file.
    /// Returns the removed alert (for accessing its on_click), or nil if not found.
    @discardableResult
    func remove(id: String) -> Alert? {
        let alert = load(id: id)
        let fileURL = alertsDir.appendingPathComponent("\(id).json")
        try? FileManager.default.removeItem(at: fileURL)
        return alert
    }

    /// List all alerts, sorted by creation time (oldest first).
    /// Optionally filter by group name.
    func list(group: String? = nil) -> [Alert] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: alertsDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var alerts: [Alert] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let alert = try? decoder.decode(Alert.self, from: data) else { continue }

            if let group = group, alert.group != group { continue }
            alerts.append(alert)
        }

        return alerts.sorted { $0.createdAt < $1.createdAt }
    }

    /// Count alerts. Optionally filter by group.
    func count(group: String? = nil) -> Int {
        list(group: group).count
    }

    /// Remove all alerts. Optionally filter by group.
    /// Returns the removed alerts.
    @discardableResult
    func clear(group: String? = nil) -> [Alert] {
        let alerts = list(group: group)
        for alert in alerts {
            remove(id: alert.id)
        }
        return alerts
    }
}
