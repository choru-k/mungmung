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

    func testListGroupFilter() {
        run("add", "--title", "A", "--message", "M", "--group", "work")
        run("add", "--title", "B", "--message", "M", "--group", "personal")

        let result = run("list", "--group", "work")
        XCTAssertTrue(result.stdout.contains("A"))
        XCTAssertFalse(result.stdout.contains("B"))
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

    func testCountGroupFilter() {
        run("add", "--title", "A", "--message", "M", "--group", "work")
        run("add", "--title", "B", "--message", "M", "--group", "personal")

        let result = run("count", "--group", "work")
        XCTAssertTrue(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
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

    func testClearByGroup() {
        run("add", "--title", "A", "--message", "M", "--group", "work")
        run("add", "--title", "B", "--message", "M", "--group", "personal")

        let result = run("clear", "--group", "work")
        XCTAssertTrue(result.stdout.contains("1 alert"))

        let countResult = run("count")
        XCTAssertTrue(countResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    // MARK: - lifecycle

    func testFullLifecycle() {
        // Add
        let addResult = run("add", "--title", "Lifecycle", "--message", "Test", "--group", "test")
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

    // MARK: - unknown command

    func testUnknownCommandExitsOne() {
        let result = run("foobar")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("Unknown command"))
    }
}
