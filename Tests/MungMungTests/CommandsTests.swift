import XCTest
import Foundation
@testable import MungMung

final class CommandsTests: XCTestCase {

    var tempDir: URL!
    var store: AlertStore!
    var mockNotifications: MockNotificationManager!
    var mockShell: MockShellRunner!
    var outputCapture: OutputCapture!
    var errorCapture: OutputCapture!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mung-test-\(UUID().uuidString)")
        store = AlertStore(baseDir: tempDir)
        mockNotifications = MockNotificationManager()
        mockShell = MockShellRunner()
        outputCapture = OutputCapture()
        errorCapture = OutputCapture()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - add

    func testAddReturnsZeroAndPrintsID() {
        let code = Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, tags: [], sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertEqual(code, 0)
        XCTAssertEqual(outputCapture.lines.count, 1)
        XCTAssertFalse(outputCapture.lines[0].isEmpty, "Should print alert ID")
    }

    func testAddSavesAlertToStore() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, tags: [], sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(store.list()[0].title, "Test")
    }

    func testAddRequestsPermission() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, tags: [], sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertTrue(mockNotifications.permissionRequested)
    }

    func testAddSendsNotification() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, tags: [], sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertEqual(mockNotifications.sentAlerts.count, 1)
        XCTAssertEqual(mockNotifications.sentAlerts[0].title, "Test")
    }

    func testAddTriggersSketchybar() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, tags: [], sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertEqual(mockShell.triggerSketchybarCount, 1)
    }

    func testAddSetsOptionalFields() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: "open http://example.com", icon: "\u{1F514}", tags: ["work"],
            source: "pi-agent", session: "sess-1", kind: "update", dedupeKey: "pi:update:sess-1", sound: "default",
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        let alert = store.list()[0]
        XCTAssertEqual(alert.onClick, "open http://example.com")
        XCTAssertEqual(alert.icon, "\u{1F514}")
        XCTAssertEqual(alert.tags, ["work"])
        XCTAssertEqual(alert.source, "pi-agent")
        XCTAssertEqual(alert.session, "sess-1")
        XCTAssertEqual(alert.kind, "update")
        XCTAssertEqual(alert.dedupeKey, "pi:update:sess-1")
        XCTAssertEqual(alert.sound, "default")
    }

    func testAddWithDedupeKey_replacesExistingInSameSession() {
        Commands.add(
            title: "First",
            message: "One",
            onClick: nil,
            icon: nil,
            source: "pi-agent",
            session: "s1",
            kind: "update",
            dedupeKey: "pi:update",
            sound: nil,
            store: store,
            notifications: mockNotifications,
            shell: mockShell,
            output: outputCapture.capture,
            errorOutput: errorCapture.capture
        )

        Commands.add(
            title: "Second",
            message: "Two",
            onClick: nil,
            icon: nil,
            source: "pi-agent",
            session: "s1",
            kind: "update",
            dedupeKey: "pi:update",
            sound: nil,
            store: store,
            notifications: mockNotifications,
            shell: mockShell,
            output: outputCapture.capture,
            errorOutput: errorCapture.capture
        )

        let alerts = store.list(sessions: ["s1"], dedupeKeys: ["pi:update"])
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.title, "Second")
        XCTAssertEqual(mockNotifications.removedAlertIDsBatch.count, 1)
    }

    func testAddWithDedupeKey_doesNotReplaceAcrossSessions() {
        Commands.add(
            title: "Session One",
            message: "One",
            onClick: nil,
            icon: nil,
            source: "pi-agent",
            session: "s1",
            kind: "update",
            dedupeKey: "pi:update",
            sound: nil,
            store: store,
            notifications: mockNotifications,
            shell: mockShell,
            output: outputCapture.capture,
            errorOutput: errorCapture.capture
        )

        Commands.add(
            title: "Session Two",
            message: "Two",
            onClick: nil,
            icon: nil,
            source: "pi-agent",
            session: "s2",
            kind: "update",
            dedupeKey: "pi:update",
            sound: nil,
            store: store,
            notifications: mockNotifications,
            shell: mockShell,
            output: outputCapture.capture,
            errorOutput: errorCapture.capture
        )

        let alerts = store.list(dedupeKeys: ["pi:update"])
        XCTAssertEqual(alerts.count, 2)
    }

    // MARK: - done

    func testDoneRemovesAlertAndReturnsZero() {
        try! store.save(Alert(title: "T", message: "M"))
        let id = store.list()[0].id
        let code = Commands.done(
            id: id, run: false,
            store: store, notifications: mockNotifications, shell: mockShell,
            errorOutput: errorCapture.capture
        )
        XCTAssertEqual(code, 0)
        XCTAssertEqual(store.list().count, 0)
    }

    func testDoneRemovesNotificationAndTriggersSketchybar() {
        try! store.save(Alert(title: "T", message: "M"))
        let id = store.list()[0].id
        Commands.done(
            id: id, run: false,
            store: store, notifications: mockNotifications, shell: mockShell,
            errorOutput: errorCapture.capture
        )
        XCTAssertEqual(mockNotifications.removedAlertIDs, [id])
        XCTAssertEqual(mockShell.triggerSketchybarCount, 1)
    }

    func testDoneNonexistentIDReturnsOne() {
        let code = Commands.done(
            id: "nonexistent", run: false,
            store: store, notifications: mockNotifications, shell: mockShell,
            errorOutput: errorCapture.capture
        )
        XCTAssertEqual(code, 1)
        XCTAssertTrue(errorCapture.text.contains("alert not found"))
    }

    func testDoneWithRunExecutesOnClick() {
        let alert = Alert(title: "T", message: "M", onClick: "echo hello")
        try! store.save(alert)
        Commands.done(
            id: alert.id, run: true,
            store: store, notifications: mockNotifications, shell: mockShell,
            errorOutput: errorCapture.capture
        )
        XCTAssertEqual(mockShell.executedCommands, ["echo hello"])
    }

    func testDoneWithRunNoOnClickDoesNotExecute() {
        let alert = Alert(title: "T", message: "M")
        try! store.save(alert)
        Commands.done(
            id: alert.id, run: true,
            store: store, notifications: mockNotifications, shell: mockShell,
            errorOutput: errorCapture.capture
        )
        XCTAssertTrue(mockShell.executedCommands.isEmpty)
    }

    func testDoneWithRunFalseSkipsOnClick() {
        let alert = Alert(title: "T", message: "M", onClick: "echo hello")
        try! store.save(alert)
        Commands.done(
            id: alert.id, run: false,
            store: store, notifications: mockNotifications, shell: mockShell,
            errorOutput: errorCapture.capture
        )
        XCTAssertTrue(mockShell.executedCommands.isEmpty)
    }

    // MARK: - list

    func testListEmptyPrintsMessage() {
        Commands.list(
            json: false, tags: [],
            store: store, output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("No pending alerts"))
    }

    func testListWithAlertsPrintsTable() {
        try! store.save(Alert(title: "Test Alert", message: "Hello"))
        Commands.list(
            json: false, tags: [],
            store: store, output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("ID"))
        XCTAssertTrue(outputCapture.text.contains("TAGS"))
        XCTAssertTrue(outputCapture.text.contains("Test Alert"))
    }

    func testListJSONOutputsValidJSON() {
        try! store.save(Alert(title: "Test", message: "Hello"))
        Commands.list(
            json: true, tags: [],
            store: store, output: outputCapture.capture
        )
        let jsonData = outputCapture.text.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(parsed, "Should output valid JSON")
        let array = parsed as? [[String: Any]]
        XCTAssertEqual(array?.count, 1)
    }

    func testListEmptyJSONOutputsEmptyArray() {
        Commands.list(
            json: true, tags: [],
            store: store, output: outputCapture.capture
        )
        let trimmed = outputCapture.text
            .replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        XCTAssertEqual(trimmed, "[]")
    }

    func testListTagFilter() {
        try! store.save(Alert(title: "A", message: "M", tags: ["work"]))
        try! store.save(Alert(title: "B", message: "M", tags: ["personal"]))
        Commands.list(
            json: false, tags: ["work"],
            store: store, output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("A"))
        XCTAssertFalse(outputCapture.text.contains("B"))
    }

    func testListMetadataFilter_source() {
        try! store.save(Alert(title: "A", message: "M", source: "pi-agent"))
        try! store.save(Alert(title: "B", message: "M", source: "claude"))

        Commands.list(
            json: false,
            sources: ["pi-agent"],
            store: store,
            output: outputCapture.capture
        )

        XCTAssertTrue(outputCapture.text.contains("A"))
        XCTAssertFalse(outputCapture.text.contains("B"))
    }

    func testListMetadataFilter_dedupeKey() {
        try! store.save(Alert(title: "A", message: "M", dedupeKey: "k1"))
        try! store.save(Alert(title: "B", message: "M", dedupeKey: "k2"))

        Commands.list(
            json: true,
            dedupeKeys: ["k1"],
            store: store,
            output: outputCapture.capture
        )

        let data = outputCapture.text.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?["title"] as? String, "A")
    }

    func testListFiltersCombineWithANDAcrossDimensions() {
        try! store.save(Alert(title: "A", message: "M", tags: ["team"], source: "pi-agent", kind: "update"))
        try! store.save(Alert(title: "B", message: "M", tags: ["team"], source: "pi-agent", kind: "action"))
        try! store.save(Alert(title: "C", message: "M", tags: ["team"], source: "claude", kind: "update"))

        Commands.list(
            json: true,
            tags: ["team"],
            sources: ["pi-agent"],
            kinds: ["update"],
            store: store,
            output: outputCapture.capture
        )

        let data = outputCapture.text.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?["title"] as? String, "A")
    }

    // MARK: - count

    func testCountEmptyReturnsZero() {
        Commands.count(
            tags: [],
            store: store, output: outputCapture.capture
        )
        XCTAssertEqual(outputCapture.text, "0")
    }

    func testCountAfterAdds() {
        try! store.save(Alert(title: "A", message: "M"))
        try! store.save(Alert(title: "B", message: "M"))
        Commands.count(
            tags: [],
            store: store, output: outputCapture.capture
        )
        XCTAssertEqual(outputCapture.text, "2")
    }

    func testCountTagFilter() {
        try! store.save(Alert(title: "A", message: "M", tags: ["work"]))
        try! store.save(Alert(title: "B", message: "M", tags: ["personal"]))
        Commands.count(
            tags: ["work"],
            store: store, output: outputCapture.capture
        )
        XCTAssertEqual(outputCapture.text, "1")
    }

    func testCountMetadataFilter() {
        try! store.save(Alert(title: "A", message: "M", source: "pi-agent", session: "s1"))
        try! store.save(Alert(title: "B", message: "M", source: "pi-agent", session: "s2"))
        try! store.save(Alert(title: "C", message: "M", source: "claude", session: "s1"))

        Commands.count(
            sources: ["pi-agent"],
            sessions: ["s1"],
            store: store,
            output: outputCapture.capture
        )

        XCTAssertEqual(outputCapture.text, "1")
    }

    func testCountMetadataFilter_dedupeKey() {
        try! store.save(Alert(title: "A", message: "M", dedupeKey: "k1"))
        try! store.save(Alert(title: "B", message: "M", dedupeKey: "k1"))
        try! store.save(Alert(title: "C", message: "M", dedupeKey: "k2"))

        Commands.count(
            dedupeKeys: ["k1"],
            store: store,
            output: outputCapture.capture
        )

        XCTAssertEqual(outputCapture.text, "2")
    }

    // MARK: - clear

    func testClearRemovesAllAndPrintsCount() {
        try! store.save(Alert(title: "A", message: "M"))
        try! store.save(Alert(title: "B", message: "M"))
        let code = Commands.clear(
            tags: [],
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture
        )
        XCTAssertEqual(code, 0)
        XCTAssertEqual(store.list().count, 0)
        XCTAssertTrue(outputCapture.text.contains("2 alerts"))
    }

    func testClearRemovesNotificationsAndTriggersSketchybar() {
        try! store.save(Alert(title: "A", message: "M"))
        Commands.clear(
            tags: [],
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture
        )
        XCTAssertEqual(mockNotifications.removedAlertIDsBatch.count, 1)
        XCTAssertEqual(mockShell.triggerSketchybarCount, 1)
    }

    func testClearTagFilter() {
        try! store.save(Alert(title: "A", message: "M", tags: ["work"]))
        try! store.save(Alert(title: "B", message: "M", tags: ["personal"]))
        Commands.clear(
            tags: ["work"],
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture
        )
        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(store.list()[0].tags, ["personal"])
    }

    func testClearMetadataFilter() {
        try! store.save(Alert(title: "A", message: "M", source: "pi-agent", kind: "update"))
        try! store.save(Alert(title: "B", message: "M", source: "pi-agent", kind: "action"))
        try! store.save(Alert(title: "C", message: "M", source: "claude", kind: "update"))

        Commands.clear(
            sources: ["pi-agent"],
            kinds: ["update"],
            store: store,
            notifications: mockNotifications,
            shell: mockShell,
            output: outputCapture.capture
        )

        XCTAssertEqual(store.list().count, 2)
        let remainingTitles = Set(store.list().map { $0.title })
        XCTAssertTrue(remainingTitles.contains("B"))
        XCTAssertTrue(remainingTitles.contains("C"))
    }

    func testClearMetadataFilter_dedupeKey() {
        try! store.save(Alert(title: "A", message: "M", dedupeKey: "k1"))
        try! store.save(Alert(title: "B", message: "M", dedupeKey: "k2"))
        try! store.save(Alert(title: "C", message: "M", dedupeKey: "k1"))

        Commands.clear(
            dedupeKeys: ["k1"],
            store: store,
            notifications: mockNotifications,
            shell: mockShell,
            output: outputCapture.capture
        )

        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(store.list().first?.title, "B")
    }

    func testClearSingularGrammar() {
        try! store.save(Alert(title: "A", message: "M"))
        Commands.clear(
            tags: [],
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("1 alert."))
        XCTAssertFalse(outputCapture.text.contains("1 alerts"))
    }

    // MARK: - doctor

    func testDoctorTextOutputContainsCoreFields() {
        try! store.save(Alert(title: "A", message: "M"))

        let code = Commands.doctor(
            json: false,
            store: store,
            output: outputCapture.capture
        )

        XCTAssertEqual(code, 0)
        let text = outputCapture.text
        XCTAssertTrue(text.contains("mung doctor"))
        XCTAssertTrue(text.contains("version:"))
        XCTAssertTrue(text.contains("alerts_dir:"))
        XCTAssertTrue(text.contains("alert_count: 1"))
        XCTAssertTrue(text.contains("on_click_shell:"))
        XCTAssertTrue(text.contains("notifications_available:"))
    }

    func testDoctorJSONOutputsValidReport() {
        try! store.save(Alert(title: "A", message: "M"))

        let code = Commands.doctor(
            json: true,
            store: store,
            output: outputCapture.capture
        )

        XCTAssertEqual(code, 0)

        let data = outputCapture.text.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        let version = parsed["version"] as? String
        XCTAssertNotNil(version)
        XCTAssertFalse(version?.isEmpty ?? true)
        XCTAssertEqual(parsed["bundledExecutable"] as? Bool, false)

        let state = parsed["state"] as? [String: Any]
        XCTAssertEqual(state?["alertCount"] as? Int, 1)

        let action = parsed["actionExecution"] as? [String: Any]
        let shellPath = action?["shellPath"] as? String
        XCTAssertNotNil(shellPath)
        XCTAssertFalse(shellPath?.isEmpty ?? true)
    }

    // MARK: - version

    func testResolveVersion_prefersBundleVersion() {
        let version = Commands.resolveVersion(
            bundleVersion: "1.2.3",
            executablePath: "/tmp/mung"
        )

        XCTAssertEqual(version, "1.2.3")
    }

    func testResolveVersion_readsBundledInfoPlistViaSymlinkedExecutablePath() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mung-resolve-version-\(UUID().uuidString)")

        let macOSDir = tempDir.appendingPathComponent("Test.app/Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOSDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let infoPlistURL = tempDir.appendingPathComponent("Test.app/Contents/Info.plist")
        let plist: [String: Any] = [
            "CFBundleShortVersionString": "9.9.9",
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: infoPlistURL)

        let executableURL = macOSDir.appendingPathComponent("Test")
        try Data().write(to: executableURL)

        let symlinkDir = tempDir.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: symlinkDir, withIntermediateDirectories: true)
        let symlinkURL = symlinkDir.appendingPathComponent("mung")
        try FileManager.default.createSymbolicLink(
            atPath: symlinkURL.path,
            withDestinationPath: executableURL.path
        )

        let version = Commands.resolveVersion(
            bundleVersion: nil,
            executablePath: symlinkURL.path
        )

        XCTAssertEqual(version, "9.9.9")
    }

    func testResolveVersion_usesFallbackWhenNoBundleVersionOrBundledPath() {
        let version = Commands.resolveVersion(
            bundleVersion: nil,
            executablePath: "/tmp/non-bundled-mung"
        )

        XCTAssertEqual(version, "0.1.0")
    }

    func testVersionPrintsMung() {
        Commands.version(output: outputCapture.capture)
        XCTAssertTrue(outputCapture.text.contains("mung"))
    }

    // MARK: - help

    func testHelpContainsAllCommands() {
        Commands.help(output: outputCapture.capture)
        let text = outputCapture.text
        XCTAssertTrue(text.contains("add"))
        XCTAssertTrue(text.contains("done"))
        XCTAssertTrue(text.contains("list"))
        XCTAssertTrue(text.contains("count"))
        XCTAssertTrue(text.contains("clear"))
        XCTAssertTrue(text.contains("doctor"))
        XCTAssertTrue(text.contains("version"))
        XCTAssertTrue(text.contains("help"))
    }

    func testHelpContainsKeyFlags() {
        Commands.help(output: outputCapture.capture)
        let text = outputCapture.text
        XCTAssertTrue(text.contains("--title"))
        XCTAssertTrue(text.contains("--message"))
        XCTAssertTrue(text.contains("--json"))
        XCTAssertTrue(text.contains("--run"))
        XCTAssertTrue(text.contains("--tag"))
        XCTAssertTrue(text.contains("--source"))
        XCTAssertTrue(text.contains("--session"))
        XCTAssertTrue(text.contains("--kind"))
        XCTAssertTrue(text.contains("--dedupe-key"))
        XCTAssertTrue(text.contains("MUNG_DEBUG_ACTIONS"))
        XCTAssertTrue(text.contains("MUNG_DEBUG_LIFECYCLE"))
    }
}
