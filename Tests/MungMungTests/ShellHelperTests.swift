import XCTest
@testable import MungMung

final class ShellHelperTests: XCTestCase {

    func testResolveActionExecutionContext_prefersForcedShell() {
        let context = ShellHelper.resolveActionExecutionContext(environment: [
            "MUNG_ON_CLICK_SHELL": "/bin/bash",
            "SHELL": "/bin/zsh",
        ])

        XCTAssertEqual(context.shellPath, "/bin/bash")
        XCTAssertEqual(context.shellArgumentsPrefix, ["-lc"])
    }

    func testResolveActionExecutionContext_usesUserShellWhenForcedInvalid() {
        let context = ShellHelper.resolveActionExecutionContext(environment: [
            "MUNG_ON_CLICK_SHELL": "/path/does/not/exist",
            "SHELL": "/bin/zsh",
        ])

        XCTAssertEqual(context.shellPath, "/bin/zsh")
        XCTAssertEqual(context.shellArgumentsPrefix, ["-lc"])
    }

    func testResolveActionExecutionContext_fallsBackToSh() {
        let context = ShellHelper.resolveActionExecutionContext(environment: [:])

        XCTAssertEqual(context.shellPath, "/bin/sh")
        XCTAssertEqual(context.shellArgumentsPrefix, ["-c"])
    }

    func testResolveActionExecutionContext_usesWorkingDirectoryWhenExists() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mung-shell-helper-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let context = ShellHelper.resolveActionExecutionContext(environment: [
            "MUNG_ON_CLICK_CWD": tempDir.path,
        ])

        XCTAssertEqual(context.workingDirectoryPath, tempDir.path)
    }

    func testResolveActionExecutionContext_ignoresMissingWorkingDirectory() {
        let context = ShellHelper.resolveActionExecutionContext(environment: [
            "MUNG_ON_CLICK_CWD": "/path/does/not/exist",
        ])

        XCTAssertNil(context.workingDirectoryPath)
    }

    func testIsActionDebugEnabled_truthyValues() {
        XCTAssertTrue(ShellHelper.isActionDebugEnabled(environment: ["MUNG_DEBUG_ACTIONS": "1"]))
        XCTAssertTrue(ShellHelper.isActionDebugEnabled(environment: ["MUNG_DEBUG_ACTIONS": "true"]))
        XCTAssertTrue(ShellHelper.isActionDebugEnabled(environment: ["MUNG_DEBUG_ACTIONS": "yes"]))
        XCTAssertTrue(ShellHelper.isActionDebugEnabled(environment: ["MUNG_DEBUG_ACTIONS": "on"]))
    }

    func testIsActionDebugEnabled_falseWhenUnsetOrInvalid() {
        XCTAssertFalse(ShellHelper.isActionDebugEnabled(environment: [:]))
        XCTAssertFalse(ShellHelper.isActionDebugEnabled(environment: ["MUNG_DEBUG_ACTIONS": "0"]))
        XCTAssertFalse(ShellHelper.isActionDebugEnabled(environment: ["MUNG_DEBUG_ACTIONS": "no"]))
    }
}
