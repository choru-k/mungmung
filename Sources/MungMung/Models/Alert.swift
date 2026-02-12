import Foundation

/// A single mungmung alert, backed by a JSON state file on disk.
///
/// State file location: `$MUNG_DIR/alerts/<id>.json`
/// Default MUNG_DIR: `~/.local/share/mung`
///
/// Example JSON:
/// ```json
/// {
///   "id": "1738000000_a1b2c3d4",
///   "title": "Claude Code",
///   "message": "Waiting for input",
///   "on_click": "aerospace workspace Terminal",
///   "icon": "🤖",
///   "group": "claude",
///   "sound": "default",
///   "created_at": "2026-02-09T12:00:00Z"
/// }
/// ```
struct Alert: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    var onClick: String?
    var icon: String?
    var group: String?
    var sound: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, message
        case onClick = "on_click"
        case icon, group, sound
        case createdAt = "created_at"
    }

    /// Generate a unique alert ID: `{unix_timestamp}_{8_hex_chars}`
    ///
    /// The timestamp prefix makes IDs sortable by creation time.
    /// The hex suffix provides uniqueness when multiple alerts are created in the same second.
    static func generateID() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let hex = String(format: "%08x", UInt32.random(in: 0...UInt32.max))
        return "\(timestamp)_\(hex)"
    }

    /// Create a new alert with a generated ID and current timestamp.
    init(
        title: String,
        message: String,
        onClick: String? = nil,
        icon: String? = nil,
        group: String? = nil,
        sound: String? = nil
    ) {
        self.id = Alert.generateID()
        self.title = title
        self.message = message
        self.onClick = onClick
        self.icon = icon
        self.group = group
        self.sound = sound
        self.createdAt = Date()
    }

    /// Human-readable age string (e.g., "2m", "1h", "3d")
    var age: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}
