import XCTest
import Foundation

/// Integration tests that spawn the MungMung binary as a subprocess.
///
/// Each test uses a unique MUNG_DIR temp directory for isolation.
/// The binary must be built before running (`swift build`).
final class CLIIntegrationTests: XCTestCase {

    var tempDir: URL!
    var binaryURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mung-integration-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Find the binary — check common locations
        let debugBinary = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // MungMungTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent(".build/debug/MungMung")

        if FileManager.default.fileExists(atPath: debugBinary.path) {
            binaryURL = debugBinary
        } else {
            // Fallback: try relative to working directory
            binaryURL = URL(fileURLWithPath: ".build/debug/MungMung")
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    func run(_ args: String...) -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = Array(args)

        var environment = ProcessInfo.processInfo.environment
        environment["MUNG_DIR"] = tempDir.path
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try! process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return (
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    // MARK: - help

    func testHelpExitsZeroAndContainsUsage() {
        let result = run("help")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("Usage:"))
    }

    func testHelpFlag() {
        let result = run("--help")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("Usage:"))
    }

    // MARK: - version

    func testVersionExitsZeroAndContainsMung() {
        let result = run("version")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("mung"))
    }

    // MARK: - doctor

    func testDoctorExitsZeroAndContainsRuntimeInfo() {
        let result = run("doctor")

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("mung doctor"))
        XCTAssertTrue(result.stdout.contains("notifications_available:"))
        XCTAssertTrue(result.stdout.contains("mung_dir: \(tempDir.path)"))
        XCTAssertTrue(result.stdout.contains("alert_count:"))
    }

    func testDoctorJSONOutputsValidJSON() {
        let result = run("doctor", "--json")

        XCTAssertEqual(result.exitCode, 0)

        let data = result.stdout.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(parsed)

        let state = parsed?["state"] as? [String: Any]
        XCTAssertEqual(state?["mungDir"] as? String, tempDir.path)
    }

    // MARK: - add

    func testAddPrintsIDAndExitsZero() {
        let result = run("add", "--title", "Test", "--message", "Hello")
        XCTAssertEqual(result.exitCode, 0)
        let id = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(id.isEmpty, "Should print alert ID")
        XCTAssertTrue(id.contains("_"), "ID should have timestamp_hex format")
    }

    func testAddCreatesStateFile() {
        let result = run("add", "--title", "Test", "--message", "Hello")
        let id = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stateFile = tempDir.appendingPathComponent("alerts/\(id).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: stateFile.path))
    }

    func testAddMissingTitleExitsOne() {
        let result = run("add", "--message", "Hello")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("--title"))
    }

    func testAddMissingMessageExitsOne() {
        let result = run("add", "--title", "Test")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("--message"))
    }

    func testAddWithMultipleTags() {
        let result = run("add", "--title", "Test", "--message", "Hello", "--tag", "ci", "--tag", "deploy")
        XCTAssertEqual(result.exitCode, 0)

        let listResult = run("list", "--json")
        XCTAssertTrue(listResult.stdout.contains("ci"))
        XCTAssertTrue(listResult.stdout.contains("deploy"))
    }

    func testAddWithMetadataFields() {
        let result = run(
            "add",
            "--title", "Meta",
            "--message", "Payload",
            "--source", "pi-agent",
            "--session", "sess-1",
            "--kind", "update"
        )
        XCTAssertEqual(result.exitCode, 0)

        let listResult = run("list", "--json")
        let data = listResult.stdout.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let first = parsed?.first

        XCTAssertEqual(first?["source"] as? String, "pi-agent")
        XCTAssertEqual(first?["session"] as? String, "sess-1")
        XCTAssertEqual(first?["kind"] as? String, "update")
    }

    func testAddWithDedupeKey_replacesWithinSession() {
        _ = run(
            "add",
            "--title", "First",
            "--message", "One",
            "--source", "pi-agent",
            "--session", "s1",
            "--kind", "update",
            "--dedupe-key", "pi:update"
        )

        _ = run(
            "add",
            "--title", "Second",
            "--message", "Two",
            "--source", "pi-agent",
            "--session", "s1",
            "--kind", "update",
            "--dedupe-key", "pi:update"
        )

        let listResult = run("list", "--json", "--session", "s1", "--dedupe-key", "pi:update")
        let data = listResult.stdout.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(array.count, 1)
        XCTAssertEqual(array.first?["title"] as? String, "Second")
    }

    func testAddWithDedupeKey_keepsDifferentSessionsIsolated() {
        _ = run(
            "add",
            "--title", "SessionOne",
            "--message", "One",
            "--source", "pi-agent",
            "--session", "s1",
            "--kind", "update",
            "--dedupe-key", "pi:update"
        )

        _ = run(
            "add",
            "--title", "SessionTwo",
            "--message", "Two",
            "--source", "pi-agent",
            "--session", "s2",
            "--kind", "update",
            "--dedupe-key", "pi:update"
        )

        let listResult = run("list", "--json", "--dedupe-key", "pi:update")
        let data = listResult.stdout.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(array.count, 2)
    }

    // MARK: - list

    func testListEmptyStore() {
        let result = run("list")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("No pending alerts"))
    }

    func testListAfterAddContainsAlert() {
        let addResult = run("add", "--title", "MyAlert", "--message", "Hello")
        XCTAssertEqual(addResult.exitCode, 0)

        let listResult = run("list")
        XCTAssertEqual(listResult.exitCode, 0)
        XCTAssertTrue(listResult.stdout.contains("MyAlert"))
    }

    func testListJSONOutputsValidJSON() {
        run("add", "--title", "Test", "--message", "Hello")

        let result = run("list", "--json")
        XCTAssertEqual(result.exitCode, 0)

        let data = result.stdout.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed, "Should be valid JSON")
        let array = parsed as? [[String: Any]]
        XCTAssertEqual(array?.count, 1)
    }

    func testListTagFilter() {
        run("add", "--title", "A", "--message", "M", "--tag", "work")
        run("add", "--title", "B", "--message", "M", "--tag", "personal")

        let result = run("list", "--tag", "work")
        XCTAssertTrue(result.stdout.contains("A"))
        XCTAssertFalse(result.stdout.contains("B"))
    }

    func testListMetadataFilter() {
        run("add", "--title", "A", "--message", "M", "--source", "pi-agent", "--session", "s1", "--kind", "update")
        run("add", "--title", "B", "--message", "M", "--source", "pi-agent", "--session", "s1", "--kind", "action")
        run("add", "--title", "C", "--message", "M", "--source", "claude", "--session", "s1", "--kind", "update")

        let result = run("list", "--json", "--source", "pi-agent", "--kind", "update")
        let data = result.stdout.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(array.count, 1)
        XCTAssertEqual(array.first?["title"] as? String, "A")
    }

    func testListDedupeKeyFilter() {
        run("add", "--title", "A", "--message", "M", "--dedupe-key", "k1")
        run("add", "--title", "B", "--message", "M", "--dedupe-key", "k2")

        let result = run("list", "--json", "--dedupe-key", "k1")
        let data = result.stdout.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(array.count, 1)
        XCTAssertEqual(array.first?["title"] as? String, "A")
    }

    // MARK: - count

    func testCountEmptyIsZero() {
        let result = run("count")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    func testCountAfterAdds() {
        run("add", "--title", "A", "--message", "M")
        run("add", "--title", "B", "--message", "M")

        let result = run("count")
        XCTAssertTrue(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
    }

    func testCountTagFilter() {
        run("add", "--title", "A", "--message", "M", "--tag", "work")
        run("add", "--title", "B", "--message", "M", "--tag", "personal")

        let result = run("count", "--tag", "work")
        XCTAssertTrue(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    func testCountMetadataFilter() {
        run("add", "--title", "A", "--message", "M", "--source", "pi-agent", "--session", "s1")
        run("add", "--title", "B", "--message", "M", "--source", "pi-agent", "--session", "s2")
        run("add", "--title", "C", "--message", "M", "--source", "claude", "--session", "s1")

        let result = run("count", "--source", "pi-agent", "--session", "s1")
        XCTAssertTrue(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    func testCountDedupeKeyFilter() {
        run("add", "--title", "A", "--message", "M", "--session", "s1", "--dedupe-key", "k1")
        run("add", "--title", "B", "--message", "M", "--session", "s2", "--dedupe-key", "k1")
        run("add", "--title", "C", "--message", "M", "--dedupe-key", "k2")

        let result = run("count", "--dedupe-key", "k1")
        XCTAssertTrue(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
    }

    // MARK: - done

    func testDoneRemovesAlert() {
        let addResult = run("add", "--title", "Test", "--message", "Hello")
        let id = addResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        let doneResult = run("done", id)
        XCTAssertEqual(doneResult.exitCode, 0)

        let countResult = run("count")
        XCTAssertTrue(countResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    func testDoneNonexistentIDExitsOne() {
        let result = run("done", "nonexistent_id")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("alert not found"))
    }

    func testDoneMissingIDExitsOne() {
        let result = run("done")
        XCTAssertEqual(result.exitCode, 1)
    }

    // MARK: - clear

    func testClearRemovesAll() {
        run("add", "--title", "A", "--message", "M")
        run("add", "--title", "B", "--message", "M")

        let result = run("clear")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("2 alerts"))

        let countResult = run("count")
        XCTAssertTrue(countResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    func testClearByTag() {
        run("add", "--title", "A", "--message", "M", "--tag", "work")
        run("add", "--title", "B", "--message", "M", "--tag", "personal")

        let result = run("clear", "--tag", "work")
        XCTAssertTrue(result.stdout.contains("1 alert"))

        let countResult = run("count")
        XCTAssertTrue(countResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    func testClearByMetadata() {
        run("add", "--title", "A", "--message", "M", "--source", "pi-agent", "--kind", "update")
        run("add", "--title", "B", "--message", "M", "--source", "pi-agent", "--kind", "action")
        run("add", "--title", "C", "--message", "M", "--source", "claude", "--kind", "update")

        let result = run("clear", "--source", "pi-agent", "--kind", "update")
        XCTAssertTrue(result.stdout.contains("1 alert"))

        let listResult = run("list", "--json")
        let data = listResult.stdout.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        let titles = Set(array.compactMap { $0["title"] as? String })

        XCTAssertFalse(titles.contains("A"))
        XCTAssertTrue(titles.contains("B"))
        XCTAssertTrue(titles.contains("C"))
    }

    func testClearByDedupeKey() {
        run("add", "--title", "A", "--message", "M", "--session", "s1", "--dedupe-key", "k1")
        run("add", "--title", "B", "--message", "M", "--dedupe-key", "k2")
        run("add", "--title", "C", "--message", "M", "--session", "s2", "--dedupe-key", "k1")

        let result = run("clear", "--dedupe-key", "k1")
        XCTAssertTrue(result.stdout.contains("2 alerts"))

        let listResult = run("list", "--json")
        let data = listResult.stdout.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        let titles = Set(array.compactMap { $0["title"] as? String })

        XCTAssertEqual(titles, Set(["B"]))
    }

    // MARK: - lifecycle

    func testFullLifecycle() {
        // Add
        let addResult = run("add", "--title", "Lifecycle", "--message", "Test", "--tag", "test")
        XCTAssertEqual(addResult.exitCode, 0)
        let id = addResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        // List — should contain alert
        let listResult = run("list")
        XCTAssertTrue(listResult.stdout.contains("Lifecycle"))

        // Count — should be 1
        let countResult = run("count")
        XCTAssertEqual(countResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "1")

        // Done — removes it
        let doneResult = run("done", id)
        XCTAssertEqual(doneResult.exitCode, 0)

        // Count — should be 0
        let finalCount = run("count")
        XCTAssertEqual(finalCount.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "0")
    }

    func testReferenceFlow_piAdapter_updateAndActionLanes() {
        let sessionID = "pi-session-1"

        run(
            "add",
            "--title", "Pi update 1",
            "--message", "First update",
            "--source", "pi-agent",
            "--session", sessionID,
            "--kind", "update",
            "--dedupe-key", "pi:update:\(sessionID)"
        )

        run(
            "add",
            "--title", "Pi update 2",
            "--message", "Second update",
            "--source", "pi-agent",
            "--session", sessionID,
            "--kind", "update",
            "--dedupe-key", "pi:update:\(sessionID)"
        )

        run(
            "add",
            "--title", "Pi action 1",
            "--message", "Need confirmation",
            "--source", "pi-agent",
            "--session", sessionID,
            "--kind", "action",
            "--dedupe-key", "pi:action:\(sessionID)"
        )

        run(
            "add",
            "--title", "Pi action 2",
            "--message", "Need confirmation again",
            "--source", "pi-agent",
            "--session", sessionID,
            "--kind", "action",
            "--dedupe-key", "pi:action:\(sessionID)"
        )

        let countBeforeCleanup = run("count", "--source", "pi-agent", "--session", sessionID)
        XCTAssertEqual(countBeforeCleanup.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "2")

        let clearActions = run("clear", "--source", "pi-agent", "--session", sessionID, "--kind", "action")
        XCTAssertEqual(clearActions.exitCode, 0)
        XCTAssertTrue(clearActions.stdout.contains("1 alert"))

        let countAfterCleanup = run("count", "--source", "pi-agent", "--session", sessionID)
        XCTAssertEqual(countAfterCleanup.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "1")

        let listUpdates = run(
            "list",
            "--json",
            "--source", "pi-agent",
            "--session", sessionID,
            "--kind", "update",
            "--dedupe-key", "pi:update:\(sessionID)"
        )
        let updateData = listUpdates.stdout.data(using: .utf8)!
        let updates = try! JSONSerialization.jsonObject(with: updateData) as! [[String: Any]]

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?["title"] as? String, "Pi update 2")

        let listActions = run("list", "--json", "--source", "pi-agent", "--session", sessionID, "--kind", "action")
        let actionData = listActions.stdout.data(using: .utf8)!
        let actions = try! JSONSerialization.jsonObject(with: actionData) as! [[String: Any]]
        XCTAssertEqual(actions.count, 0)
    }

    func testReferenceFlow_claudeAdapter_sessionIsolation() {
        run(
            "add",
            "--title", "Claude action",
            "--message", "Need input",
            "--source", "claude",
            "--session", "claude-a",
            "--kind", "action",
            "--dedupe-key", "claude:action:claude-a"
        )

        run(
            "add",
            "--title", "Claude update A",
            "--message", "Turn finished",
            "--source", "claude",
            "--session", "claude-a",
            "--kind", "update",
            "--dedupe-key", "claude:update:claude-a"
        )

        run(
            "add",
            "--title", "Claude update B",
            "--message", "Other session",
            "--source", "claude",
            "--session", "claude-b",
            "--kind", "update",
            "--dedupe-key", "claude:update:claude-b"
        )

        let clearSessionA = run("clear", "--source", "claude", "--session", "claude-a")
        XCTAssertEqual(clearSessionA.exitCode, 0)
        XCTAssertTrue(clearSessionA.stdout.contains("2 alerts"))

        let sessionACount = run("count", "--source", "claude", "--session", "claude-a")
        XCTAssertEqual(sessionACount.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "0")

        let sessionBCount = run("count", "--source", "claude", "--session", "claude-b")
        XCTAssertEqual(sessionBCount.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "1")

        let remaining = run("list", "--json", "--source", "claude", "--session", "claude-b")
        let remainingData = remaining.stdout.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: remainingData) as! [[String: Any]]

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?["title"] as? String, "Claude update B")
        XCTAssertEqual(parsed.first?["kind"] as? String, "update")
    }

    // MARK: - unknown command

    func testUnknownCommandExitsOne() {
        let result = run("foobar")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("Unknown command"))
    }
}
