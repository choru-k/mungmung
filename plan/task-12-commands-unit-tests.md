# Task 12: Commands Unit Tests

## Overview

Write ~25 unit tests covering all 7 `Commands` methods using the mock dependencies and temp-directory `AlertStore`. Each test injects mocks to verify behavior without touching real notifications, shell, or filesystem outside the temp dir.

## Scope
- **Files:** `Tests/MungMungTests/CommandsTests.swift` (create)
- **Effort:** ~1.5h
- **Depends on:** Tasks 10 (call sites updated), 11 (mocks exist)
- **Blocks:** none

## Step 1: Write Test

**File:** `Tests/MungMungTests/CommandsTests.swift` (create)

```swift
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
            onClick: nil, icon: nil, group: nil, sound: nil,
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
            onClick: nil, icon: nil, group: nil, sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(store.list()[0].title, "Test")
    }

    func testAddRequestsPermission() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, group: nil, sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertTrue(mockNotifications.permissionRequested)
    }

    func testAddSendsNotification() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, group: nil, sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertEqual(mockNotifications.sentAlerts.count, 1)
        XCTAssertEqual(mockNotifications.sentAlerts[0].title, "Test")
    }

    func testAddTriggersSketchybar() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: nil, icon: nil, group: nil, sound: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        XCTAssertEqual(mockShell.triggerSketchybarCount, 1)
    }

    func testAddSetsOptionalFields() {
        Commands.add(
            title: "Test", message: "Hello",
            onClick: "open http://example.com", icon: "🔔", group: "work", sound: "default",
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture, errorOutput: errorCapture.capture
        )
        let alert = store.list()[0]
        XCTAssertEqual(alert.onClick, "open http://example.com")
        XCTAssertEqual(alert.icon, "🔔")
        XCTAssertEqual(alert.group, "work")
        XCTAssertEqual(alert.sound, "default")
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
            json: false, group: nil,
            store: store, output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("No pending alerts"))
    }

    func testListWithAlertsPrintsTable() {
        try! store.save(Alert(title: "Test Alert", message: "Hello"))
        Commands.list(
            json: false, group: nil,
            store: store, output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("ID"))
        XCTAssertTrue(outputCapture.text.contains("Test Alert"))
    }

    func testListJSONOutputsValidJSON() {
        try! store.save(Alert(title: "Test", message: "Hello"))
        Commands.list(
            json: true, group: nil,
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
            json: true, group: nil,
            store: store, output: outputCapture.capture
        )
        XCTAssertEqual(outputCapture.text.trimmingCharacters(in: .whitespacesAndNewlines), "[]")
    }

    func testListGroupFilter() {
        try! store.save(Alert(title: "A", message: "M", group: "work"))
        try! store.save(Alert(title: "B", message: "M", group: "personal"))
        Commands.list(
            json: false, group: "work",
            store: store, output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("A"))
        XCTAssertFalse(outputCapture.text.contains("B"))
    }

    // MARK: - count

    func testCountEmptyReturnsZero() {
        Commands.count(
            group: nil,
            store: store, output: outputCapture.capture
        )
        XCTAssertEqual(outputCapture.text, "0")
    }

    func testCountAfterAdds() {
        try! store.save(Alert(title: "A", message: "M"))
        try! store.save(Alert(title: "B", message: "M"))
        Commands.count(
            group: nil,
            store: store, output: outputCapture.capture
        )
        XCTAssertEqual(outputCapture.text, "2")
    }

    func testCountGroupFilter() {
        try! store.save(Alert(title: "A", message: "M", group: "work"))
        try! store.save(Alert(title: "B", message: "M", group: "personal"))
        Commands.count(
            group: "work",
            store: store, output: outputCapture.capture
        )
        XCTAssertEqual(outputCapture.text, "1")
    }

    // MARK: - clear

    func testClearRemovesAllAndPrintsCount() {
        try! store.save(Alert(title: "A", message: "M"))
        try! store.save(Alert(title: "B", message: "M"))
        let code = Commands.clear(
            group: nil,
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
            group: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture
        )
        XCTAssertEqual(mockNotifications.removedAlertIDsBatch.count, 1)
        XCTAssertEqual(mockShell.triggerSketchybarCount, 1)
    }

    func testClearGroupFilter() {
        try! store.save(Alert(title: "A", message: "M", group: "work"))
        try! store.save(Alert(title: "B", message: "M", group: "personal"))
        Commands.clear(
            group: "work",
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture
        )
        XCTAssertEqual(store.list().count, 1)
        XCTAssertEqual(store.list()[0].group, "personal")
    }

    func testClearSingularGrammar() {
        try! store.save(Alert(title: "A", message: "M"))
        Commands.clear(
            group: nil,
            store: store, notifications: mockNotifications, shell: mockShell,
            output: outputCapture.capture
        )
        XCTAssertTrue(outputCapture.text.contains("1 alert."))
        XCTAssertFalse(outputCapture.text.contains("1 alerts"))
    }

    // MARK: - version

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
        XCTAssertTrue(text.contains("--group"))
    }
}
```

**What this tests:** All 7 `Commands` methods using injected mocks — verifying exit codes, output, state changes, notification calls, shell calls, and edge cases.

## Step 2: Verify Test Fails

```bash
swift test --filter CommandsTests 2>&1
```

**Expected output pattern:** Tests should compile and run. If Task 9-11 are done correctly, tests should pass on first run (since we're writing tests for existing, now-refactored code).

## Step 3: Implement

No additional implementation needed — the test file itself is the deliverable. The `Commands` refactoring (Task 9) and mocks (Task 11) provide everything needed.

If any tests fail due to API mismatches, adjust the test calls to match the actual `Commands` method signatures from Task 9.

## Step 4: Verify Test Passes

```bash
swift test 2>&1
```

**Expected output:** All tests pass (45 existing + ~25 new CommandsTests).

## Step 5: Commit

```bash
git add Tests/MungMungTests/CommandsTests.swift
git commit -m "test(commands): add ~25 unit tests for all Commands methods"
```

## Error Protocol

If any step fails:

1. **Strike 1:** Read the error message carefully. Fix the most likely cause. Re-run.
2. **Strike 2:** Re-read this task file and main.md. Try an alternative approach. Re-run.
3. **Strike 3:** STOP. Log the error in main.md's Log section. Do not proceed.

## Exit Criteria

- [ ] `CommandsTests.swift` exists in `Tests/MungMungTests/`
- [ ] All ~25 Commands tests pass
- [ ] All 45 existing tests still pass
- [ ] Tests cover: add, done, list, count, clear, version, help
- [ ] Tests verify: exit codes, output, state changes, mock interactions, edge cases
