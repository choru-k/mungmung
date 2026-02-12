# Task 2: Alert Model & State Store

## Background

mungmung is a stateful notification manager. Every notification is backed by a JSON state file on disk at `$MUNG_DIR/alerts/<id>.json` (default: `~/.local/share/mung/alerts/`). This means any tool — the app, shell scripts, sketchybar plugins — can read/write alert state.

This task creates two files:
1. **`Alert`** — a `Codable` struct representing a single alert
2. **`AlertStore`** — a class that handles CRUD operations on the state directory

## Dependencies

- **Task 1** (Project Setup) — Package.swift and directory structure must exist

## Files to Create

| File | Purpose |
|------|---------|
| `Sources/MungMung/Models/Alert.swift` | Alert data model |
| `Sources/MungMung/Services/AlertStore.swift` | State file CRUD operations |

## Implementation

### `Sources/MungMung/Models/Alert.swift`

```swift
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
struct Alert: Codable, Identifiable {
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
```

### `Sources/MungMung/Services/AlertStore.swift`

```swift
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
```

## Verification

1. **Build compiles:**
   ```bash
   swift build
   ```

2. **Manual test — create and read an alert:**
   Add a temporary test in `main()`:
   ```swift
   let store = AlertStore()
   let alert = Alert(title: "Test", message: "Hello", group: "test")
   try! store.save(alert)
   print("Saved:", alert.id)
   print("Count:", store.count())
   print("List:", store.list())
   store.remove(id: alert.id)
   print("After remove:", store.count())
   ```
   Run with `swift run MungMung` and verify output.

3. **Check state file on disk:**
   ```bash
   cat ~/.local/share/mung/alerts/*.json
   ```
   Should be valid JSON matching the Alert schema from SPEC.md.

4. **Check $MUNG_DIR override:**
   ```bash
   MUNG_DIR=/tmp/mung-test swift run MungMung
   ls /tmp/mung-test/alerts/
   ```

## Architecture Context

The alert state system is the backbone of mungmung. Every component interacts with it:

- **`mung add`** (Task 5) — creates an Alert, calls `store.save()`, then sends a notification
- **`mung done`** (Task 5) — calls `store.remove()`, then removes the notification
- **`mung list`** (Task 5) — calls `store.list()` and prints results
- **`mung count`** (Task 5) — calls `store.count()` and prints the number
- **`mung clear`** (Task 5) — calls `store.clear()` and removes all notifications
- **Notification click** (Task 6) — reads alert from store to get `on_click`, then removes it
- **Sketchybar plugin** (Task 7) — reads `$MUNG_DIR/alerts/*.json` directly from shell

The JSON format is intentionally simple so shell scripts can read it with `jq`:
```bash
jq -r '.title' ~/.local/share/mung/alerts/1738000000_a1b2c3d4.json
```

State directory structure:
```
~/.local/share/mung/          # $MUNG_DIR (configurable via env var)
└── alerts/
    ├── 1738000000_a1b2c3d4.json
    ├── 1738000060_b2c3d4e5.json
    └── ...
```

## Test Plan

### Production code change for testability

`AlertStore` gains an `init(baseDir: URL)` so tests can inject a temp directory instead of relying on `$MUNG_DIR`:

```swift
init(baseDir: URL) {
    self.baseDir = baseDir
}
```

### `Tests/MungMungTests/AlertTests.swift` (13 tests)

| Test | What it verifies |
|------|-----------------|
| `testGenerateID_format` | ID matches `^\d+_[0-9a-f]{8}$` |
| `testGenerateID_uniqueness` | 100 generated IDs are all unique |
| `testConvenienceInit_setsIdAndCreatedAt` | Init auto-generates id and sets createdAt to now |
| `testConvenienceInit_optionalFieldsDefaultToNil` | onClick, icon, group, sound default to nil |
| `testConvenienceInit_setsOptionalFields` | All optional fields are set when provided |
| `testCodableRoundTrip_allFields` | Encode → decode preserves all fields |
| `testCodableRoundTrip_minimalFields` | Encode → decode with only required fields |
| `testJSONKeyMapping` | JSON uses `on_click`/`created_at` (not camelCase) |
| `testDecodeFromExternalJSON` | Decode from hand-written JSON matching SPEC format |
| `testAge_seconds` | 30s ago → `"30s"` |
| `testAge_minutes` | 120s ago → `"2m"` |
| `testAge_hours` | 3600s ago → `"1h"` |
| `testAge_days` | 3d ago → `"3d"` |

**Helper**: `makeAlert(secondsAgo:)` decodes from JSON with a controlled `created_at` to test the `age` property without modifying the model.

### `Tests/MungMungTests/AlertStoreTests.swift` (18 tests)

Each test gets a unique UUID-based temp directory, cleaned up in `tearDown`.

| Test | What it verifies |
|------|-----------------|
| `testSaveAndLoad_roundTrip` | Save then load returns matching alert |
| `testSave_createsFileOnDisk` | File exists at `alertsDir/<id>.json` after save |
| `testSave_createsDirectoryIfNeeded` | `alertsDir` is auto-created on first save |
| `testLoad_nonexistentID_returnsNil` | Loading unknown ID returns nil |
| `testRemove_returnsRemovedAlert` | Remove returns the alert that was removed |
| `testRemove_deletesFileFromDisk` | File is gone after remove |
| `testRemove_nonexistentID_returnsNil` | Removing unknown ID returns nil |
| `testRemove_alertNoLongerLoadable` | Load returns nil after remove |
| `testList_empty` | List on empty store returns `[]` |
| `testList_returnsSortedByCreationTime` | Alerts saved out-of-order are listed chronologically |
| `testList_filteredByGroup` | Group filter returns only matching alerts |
| `testCount_empty` | Count on empty store returns 0 |
| `testCount_afterSaves` | Count reflects number of saved alerts |
| `testCount_filteredByGroup` | Count with group filter |
| `testClear_removesAllAlerts` | Clear drops count to 0 |
| `testClear_returnsRemovedAlerts` | Clear returns the removed alerts |
| `testClear_byGroup_onlyRemovesMatching` | Group-scoped clear leaves other groups intact |
| `testClear_byGroup_nonexistentGroup_removesNothing` | Clear with unknown group is a no-op |

**Helper**: `makeAlert(title:createdAt:)` decodes from JSON with a controlled timestamp to test sort order.
