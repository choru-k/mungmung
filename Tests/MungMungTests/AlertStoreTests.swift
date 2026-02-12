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

    func testList_filteredByGroup() throws {
        let ciAlert = Alert(title: "CI", message: "M", group: "ci")
        let devAlert = Alert(title: "Dev", message: "M", group: "dev")
        let noGroup = Alert(title: "No Group", message: "M")

        try store.save(ciAlert)
        try store.save(devAlert)
        try store.save(noGroup)

        let ciAlerts = store.list(group: "ci")
        XCTAssertEqual(ciAlerts.count, 1)
        XCTAssertEqual(ciAlerts[0].title, "CI")

        let devAlerts = store.list(group: "dev")
        XCTAssertEqual(devAlerts.count, 1)
        XCTAssertEqual(devAlerts[0].title, "Dev")

        let allAlerts = store.list()
        XCTAssertEqual(allAlerts.count, 3)
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

    func testCount_filteredByGroup() throws {
        try store.save(Alert(title: "A", message: "M", group: "ci"))
        try store.save(Alert(title: "B", message: "M", group: "ci"))
        try store.save(Alert(title: "C", message: "M", group: "dev"))

        XCTAssertEqual(store.count(group: "ci"), 2)
        XCTAssertEqual(store.count(group: "dev"), 1)
        XCTAssertEqual(store.count(), 3)
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

    func testClear_byGroup_onlyRemovesMatching() throws {
        try store.save(Alert(title: "CI1", message: "M", group: "ci"))
        try store.save(Alert(title: "CI2", message: "M", group: "ci"))
        try store.save(Alert(title: "Dev", message: "M", group: "dev"))

        let removed = store.clear(group: "ci")
        XCTAssertEqual(removed.count, 2)
        XCTAssertEqual(store.count(), 1)
        XCTAssertEqual(store.list()[0].title, "Dev")
    }

    func testClear_byGroup_nonexistentGroup_removesNothing() throws {
        try store.save(Alert(title: "A", message: "M", group: "ci"))

        let removed = store.clear(group: "nonexistent")
        XCTAssertTrue(removed.isEmpty)
        XCTAssertEqual(store.count(), 1)
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
