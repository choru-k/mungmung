import XCTest
@testable import MungMung

final class AlertTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - ID Generation

    func testGenerateID_format() {
        let id = Alert.generateID()
        let pattern = #"^\d+_[0-9a-f]{8}$"#
        XCTAssertNotNil(id.range(of: pattern, options: .regularExpression),
                        "ID '\(id)' should match format 'timestamp_8hexchars'")
    }

    func testGenerateID_uniqueness() {
        let ids = (0..<100).map { _ in Alert.generateID() }
        let uniqueIDs = Set(ids)
        XCTAssertEqual(uniqueIDs.count, ids.count, "Generated IDs should be unique")
    }

    // MARK: - Convenience Init

    func testConvenienceInit_setsIdAndCreatedAt() {
        let alert = Alert(title: "T", message: "M")
        XCTAssertFalse(alert.id.isEmpty)
        XCTAssertLessThan(abs(alert.createdAt.timeIntervalSinceNow), 1.0)
    }

    func testConvenienceInit_optionalFieldsDefaultToNil() {
        let alert = Alert(title: "T", message: "M")
        XCTAssertNil(alert.onClick)
        XCTAssertNil(alert.icon)
        XCTAssertNil(alert.group)
        XCTAssertNil(alert.sound)
    }

    func testConvenienceInit_setsOptionalFields() {
        let alert = Alert(
            title: "T", message: "M",
            onClick: "open .", icon: "🔔",
            group: "ci", sound: "default"
        )
        XCTAssertEqual(alert.onClick, "open .")
        XCTAssertEqual(alert.icon, "🔔")
        XCTAssertEqual(alert.group, "ci")
        XCTAssertEqual(alert.sound, "default")
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip_allFields() throws {
        let original = Alert(
            title: "Claude Code", message: "Waiting for input",
            onClick: "aerospace workspace Terminal",
            icon: "🤖", group: "claude", sound: "default"
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Alert.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertEqual(decoded.onClick, original.onClick)
        XCTAssertEqual(decoded.icon, original.icon)
        XCTAssertEqual(decoded.group, original.group)
        XCTAssertEqual(decoded.sound, original.sound)
        XCTAssertEqual(
            Int(decoded.createdAt.timeIntervalSince1970),
            Int(original.createdAt.timeIntervalSince1970)
        )
    }

    func testCodableRoundTrip_minimalFields() throws {
        let original = Alert(title: "T", message: "M")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Alert.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertNil(decoded.onClick)
        XCTAssertNil(decoded.icon)
        XCTAssertNil(decoded.group)
        XCTAssertNil(decoded.sound)
    }

    // MARK: - JSON Key Mapping

    func testJSONKeyMapping() throws {
        let alert = Alert(title: "T", message: "M", onClick: "open .")
        let data = try encoder.encode(alert)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"on_click\""), "JSON should use 'on_click' not 'onClick'")
        XCTAssertTrue(json.contains("\"created_at\""), "JSON should use 'created_at' not 'createdAt'")
        XCTAssertFalse(json.contains("\"onClick\""))
        XCTAssertFalse(json.contains("\"createdAt\""))
    }

    func testDecodeFromExternalJSON() throws {
        let json = """
        {
          "id": "1738000000_a1b2c3d4",
          "title": "Claude Code",
          "message": "Waiting for input",
          "on_click": "aerospace workspace Terminal",
          "icon": "🤖",
          "group": "claude",
          "sound": "default",
          "created_at": "2026-02-09T12:00:00Z"
        }
        """
        let alert = try decoder.decode(Alert.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(alert.id, "1738000000_a1b2c3d4")
        XCTAssertEqual(alert.title, "Claude Code")
        XCTAssertEqual(alert.onClick, "aerospace workspace Terminal")
    }

    // MARK: - Age Computed Property

    func testAge_seconds() {
        let alert = makeAlert(secondsAgo: 30)
        XCTAssertEqual(alert.age, "30s")
    }

    func testAge_minutes() {
        let alert = makeAlert(secondsAgo: 120)
        XCTAssertEqual(alert.age, "2m")
    }

    func testAge_hours() {
        let alert = makeAlert(secondsAgo: 3600)
        XCTAssertEqual(alert.age, "1h")
    }

    func testAge_days() {
        let alert = makeAlert(secondsAgo: 86400 * 3)
        XCTAssertEqual(alert.age, "3d")
    }

    // MARK: - Hashable

    func testHashable_sameAlertHashesEqual() {
        let alert = Alert(title: "T", message: "M")
        XCTAssertEqual(alert.hashValue, alert.hashValue)
    }

    func testHashable_conformance() {
        let a1 = Alert(title: "A", message: "1")
        let a2 = Alert(title: "B", message: "2")
        var set = Set<Alert>()
        set.insert(a1)
        set.insert(a2)
        set.insert(a1) // duplicate

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Helpers

    private func makeAlert(secondsAgo: TimeInterval) -> Alert {
        let createdAt = Date().addingTimeInterval(-secondsAgo)
        let formatter = ISO8601DateFormatter()
        let json = """
        {
          "id": "test_00000001",
          "title": "T",
          "message": "M",
          "created_at": "\(formatter.string(from: createdAt))"
        }
        """
        return try! decoder.decode(Alert.self, from: json.data(using: .utf8)!)
    }
}
