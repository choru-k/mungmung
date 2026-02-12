import XCTest
@testable import MungMung

final class EntryPointTests: XCTestCase {

    // MARK: - Empty args → GUI

    func testEmptyArgs_returnsFalse() {
        XCTAssertFalse(MungMungEntry.isCLIMode([]))
    }

    // MARK: - Subcommands → CLI

    func testSubcommand_add() {
        XCTAssertTrue(MungMungEntry.isCLIMode(["add", "--title", "T", "--message", "M"]))
    }

    func testSubcommand_help() {
        XCTAssertTrue(MungMungEntry.isCLIMode(["help"]))
    }

    // MARK: - CLI flags → CLI

    func testFlag_dashDashHelp() {
        XCTAssertTrue(MungMungEntry.isCLIMode(["--help"]))
    }

    func testFlag_dashH() {
        XCTAssertTrue(MungMungEntry.isCLIMode(["-h"]))
    }

    // MARK: - macOS launch-service flags → GUI

    func testMacOS_NSDocumentRevisionsDebugMode() {
        XCTAssertFalse(MungMungEntry.isCLIMode(["-NSDocumentRevisionsDebugMode", "YES"]))
    }

    func testMacOS_ApplePersistenceIgnoreState() {
        XCTAssertFalse(MungMungEntry.isCLIMode(["-ApplePersistenceIgnoreState", "YES"]))
    }

    func testMacOS_AppleLanguages() {
        XCTAssertFalse(MungMungEntry.isCLIMode(["-AppleLanguages", "(en)"]))
    }
}
