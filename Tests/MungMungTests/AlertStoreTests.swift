import XCTest
@testable import MungMung

final class AlertStoreTests: XCTestCase {

    private var tempDir: URL!
    private var store: AlertStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MungMungTests-\(UUID().uuidString)")
        store = AlertStore(baseDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        store = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Save & Load

    func testSaveAndLoad_roundTrip() throws {
        let alert = Alert(title: "Test", message: "Hello")
        try store.save(alert)

        let loaded = store.load(id: alert.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, alert.id)
        XCTAssertEqual(loaded?.title, "Test")
        XCTAssertEqual(loaded?.message, "Hello")
    }

    func testSave_createsFileOnDisk() throws {
        let alert = Alert(title: "T", message: "M")
        let fileURL = try store.save(alert)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSave_createsDirectoryIfNeeded() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.alertsDir.path))

        let alert = Alert(title: "T", message: "M")
        try store.save(alert)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.alertsDir.path))
    }

    // MARK: - Load

    func testLoad_nonexistentID_returnsNil() {
        let result = store.load(id: "nonexistent_00000000")
        XCTAssertNil(result)
    }

    // MARK: - Remove

    func testRemove_returnsRemovedAlert() throws {
        let alert = Alert(title: "T", message: "M")
        try store.save(alert)

        let removed = store.remove(id: alert.id)
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.id, alert.id)
    }

    func testRemove_deletesFileFromDisk() throws {
        let alert = Alert(title: "T", message: "M")
        let fileURL = try store.save(alert)

        store.remove(id: alert.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRemove_nonexistentID_returnsNil() {
        let result = store.remove(id: "nonexistent_00000000")
        XCTAssertNil(result)
    }

    func testRemove_alertNoLongerLoadable() throws {
        let alert = Alert(title: "T", message: "M")
        try store.save(alert)
        store.remove(id: alert.id)

        XCTAssertNil(store.load(id: alert.id))
    }

    // MARK: - List

    func testList_empty() {
        let alerts = store.list()
        XCTAssertTrue(alerts.isEmpty)
    }

    func testList_returnsSortedByCreationTime() throws {
        let now = Date()
        let alert1 = makeAlert(title: "First", createdAt: now.addingTimeInterval(-60))
        let alert2 = makeAlert(title: "Second", createdAt: now.addingTimeInterval(-30))
        let alert3 = makeAlert(title: "Third", createdAt: now)

        // Save in non-chronological order
        try store.save(alert3)
        try store.save(alert1)
        try store.save(alert2)

        let listed = store.list()
        XCTAssertEqual(listed.count, 3)
        XCTAssertEqual(listed[0].title, "First")
        XCTAssertEqual(listed[1].title, "Second")
        XCTAssertEqual(listed[2].title, "Third")
    }

    func testList_filteredByTag() throws {
        let ciAlert = Alert(title: "CI", message: "M", tags: ["ci"])
        let devAlert = Alert(title: "Dev", message: "M", tags: ["dev"])
        let noTags = Alert(title: "No Tags", message: "M")

        try store.save(ciAlert)
        try store.save(devAlert)
        try store.save(noTags)

        let ciAlerts = store.list(tags: ["ci"])
        XCTAssertEqual(ciAlerts.count, 1)
        XCTAssertEqual(ciAlerts[0].title, "CI")

        let devAlerts = store.list(tags: ["dev"])
        XCTAssertEqual(devAlerts.count, 1)
        XCTAssertEqual(devAlerts[0].title, "Dev")

        let allAlerts = store.list()
        XCTAssertEqual(allAlerts.count, 3)
    }

    func testList_multiTagORFilter() throws {
        let ciAlert = Alert(title: "CI", message: "M", tags: ["ci"])
        let devAlert = Alert(title: "Dev", message: "M", tags: ["dev"])
        let bothAlert = Alert(title: "Both", message: "M", tags: ["ci", "dev"])
        let otherAlert = Alert(title: "Other", message: "M", tags: ["prod"])

        try store.save(ciAlert)
        try store.save(devAlert)
        try store.save(bothAlert)
        try store.save(otherAlert)

        // Filter by ci OR dev — should match 3 alerts
        let filtered = store.list(tags: ["ci", "dev"])
        XCTAssertEqual(filtered.count, 3)
        let titles = Set(filtered.map { $0.title })
        XCTAssertTrue(titles.contains("CI"))
        XCTAssertTrue(titles.contains("Dev"))
        XCTAssertTrue(titles.contains("Both"))
    }

    func testList_sourceORFilter() throws {
        try store.save(Alert(title: "A", message: "M", source: "pi-agent"))
        try store.save(Alert(title: "B", message: "M", source: "claude"))
        try store.save(Alert(title: "C", message: "M", source: "other"))

        let filtered = store.list(sources: ["pi-agent", "claude"])
        XCTAssertEqual(filtered.count, 2)
        let titles = Set(filtered.map { $0.title })
        XCTAssertTrue(titles.contains("A"))
        XCTAssertTrue(titles.contains("B"))
    }

    func testList_dedupeKeyFilter() throws {
        try store.save(Alert(title: "A", message: "M", dedupeKey: "k1"))
        try store.save(Alert(title: "B", message: "M", dedupeKey: "k2"))
        try store.save(Alert(title: "C", message: "M", dedupeKey: "k1"))

        let filtered = store.list(dedupeKeys: ["k1"])
        XCTAssertEqual(filtered.count, 2)
        let titles = Set(filtered.map { $0.title })
        XCTAssertTrue(titles.contains("A"))
        XCTAssertTrue(titles.contains("C"))
    }

    func testList_filtersUseANDAcrossDimensions() throws {
        try store.save(Alert(title: "A", message: "M", tags: ["work"], source: "pi-agent", session: "s1", kind: "update"))
        try store.save(Alert(title: "B", message: "M", tags: ["work"], source: "pi-agent", session: "s1", kind: "action"))
        try store.save(Alert(title: "C", message: "M", tags: ["work"], source: "claude", session: "s1", kind: "update"))

        let filtered = store.list(tags: ["work"], sources: ["pi-agent"], sessions: ["s1"], kinds: ["update"])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "A")
    }

    // MARK: - Count

    func testCount_empty() {
        XCTAssertEqual(store.count(), 0)
    }

    func testCount_afterSaves() throws {
        try store.save(Alert(title: "A", message: "M"))
        try store.save(Alert(title: "B", message: "M"))
        XCTAssertEqual(store.count(), 2)
    }

    func testCount_filteredByTag() throws {
        try store.save(Alert(title: "A", message: "M", tags: ["ci"]))
        try store.save(Alert(title: "B", message: "M", tags: ["ci"]))
        try store.save(Alert(title: "C", message: "M", tags: ["dev"]))

        XCTAssertEqual(store.count(tags: ["ci"]), 2)
        XCTAssertEqual(store.count(tags: ["dev"]), 1)
        XCTAssertEqual(store.count(), 3)
    }

    func testCount_filteredByMetadata() throws {
        try store.save(Alert(title: "A", message: "M", source: "pi-agent", session: "s1"))
        try store.save(Alert(title: "B", message: "M", source: "pi-agent", session: "s2"))
        try store.save(Alert(title: "C", message: "M", source: "claude", session: "s1"))

        XCTAssertEqual(store.count(sources: ["pi-agent"]), 2)
        XCTAssertEqual(store.count(sources: ["pi-agent"], sessions: ["s1"]), 1)
        XCTAssertEqual(store.count(kinds: ["update"]), 0)
    }

    func testCount_filteredByDedupeKey() throws {
        try store.save(Alert(title: "A", message: "M", dedupeKey: "k1"))
        try store.save(Alert(title: "B", message: "M", dedupeKey: "k2"))
        try store.save(Alert(title: "C", message: "M", dedupeKey: "k1"))

        XCTAssertEqual(store.count(dedupeKeys: ["k1"]), 2)
        XCTAssertEqual(store.count(dedupeKeys: ["k2"]), 1)
    }

    // MARK: - Clear

    func testClear_removesAllAlerts() throws {
        try store.save(Alert(title: "A", message: "M"))
        try store.save(Alert(title: "B", message: "M"))
        XCTAssertEqual(store.count(), 2)

        store.clear()
        XCTAssertEqual(store.count(), 0)
    }

    func testClear_returnsRemovedAlerts() throws {
        try store.save(Alert(title: "A", message: "M"))
        try store.save(Alert(title: "B", message: "M"))

        let removed = store.clear()
        XCTAssertEqual(removed.count, 2)
    }

    func testClear_byTag_onlyRemovesMatching() throws {
        try store.save(Alert(title: "CI1", message: "M", tags: ["ci"]))
        try store.save(Alert(title: "CI2", message: "M", tags: ["ci"]))
        try store.save(Alert(title: "Dev", message: "M", tags: ["dev"]))

        let removed = store.clear(tags: ["ci"])
        XCTAssertEqual(removed.count, 2)
        XCTAssertEqual(store.count(), 1)
        XCTAssertEqual(store.list()[0].title, "Dev")
    }

    func testClear_byTag_nonexistentTag_removesNothing() throws {
        try store.save(Alert(title: "A", message: "M", tags: ["ci"]))

        let removed = store.clear(tags: ["nonexistent"])
        XCTAssertTrue(removed.isEmpty)
        XCTAssertEqual(store.count(), 1)
    }

    func testClear_byMetadata_onlyRemovesMatching() throws {
        try store.save(Alert(title: "A", message: "M", source: "pi-agent", kind: "update"))
        try store.save(Alert(title: "B", message: "M", source: "pi-agent", kind: "action"))
        try store.save(Alert(title: "C", message: "M", source: "claude", kind: "update"))

        let removed = store.clear(sources: ["pi-agent"], kinds: ["update"])
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first?.title, "A")
        XCTAssertEqual(store.count(), 2)
    }

    func testClear_byDedupeKey_onlyRemovesMatching() throws {
        try store.save(Alert(title: "A", message: "M", dedupeKey: "k1"))
        try store.save(Alert(title: "B", message: "M", dedupeKey: "k2"))
        try store.save(Alert(title: "C", message: "M", dedupeKey: "k1"))

        let removed = store.clear(dedupeKeys: ["k1"])
        XCTAssertEqual(removed.count, 2)
        XCTAssertEqual(store.count(), 1)
        XCTAssertEqual(store.list().first?.title, "B")
    }

    // MARK: - Helpers

    private func makeAlert(title: String, createdAt: Date) -> Alert {
        let formatter = ISO8601DateFormatter()
        let id = Alert.generateID()
        let json = """
        {
          "id": "\(id)",
          "title": "\(title)",
          "message": "M",
          "created_at": "\(formatter.string(from: createdAt))"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(Alert.self, from: json.data(using: .utf8)!)
    }
}
