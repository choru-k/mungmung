@testable import MungMung
import XCTest

final class NotificationManagerTests: XCTestCase {

    // MARK: - isBundledExecutable

    func testIsBundledExecutable_appBundlePath_returnsTrue() {
        let path = "/Applications/MungMung.app/Contents/MacOS/MungMung"
        XCTAssertTrue(NotificationManager.isBundledExecutable(resolvedPath: path))
    }

    func testIsBundledExecutable_homebrewSymlinkResolved_returnsTrue() {
        // After symlink resolution the real path is inside the .app bundle
        let path = "/Applications/MungMung.app/Contents/MacOS/MungMung"
        XCTAssertTrue(NotificationManager.isBundledExecutable(resolvedPath: path))
    }

    func testIsBundledExecutable_debugBuildPath_returnsFalse() {
        let path = "/Users/dev/project/.build/debug/MungMung"
        XCTAssertFalse(NotificationManager.isBundledExecutable(resolvedPath: path))
    }

    func testIsBundledExecutable_releaseBuildPath_returnsFalse() {
        let path = "/Users/dev/project/.build/release/MungMung"
        XCTAssertFalse(NotificationManager.isBundledExecutable(resolvedPath: path))
    }

    func testIsBundledExecutable_usrLocalBin_returnsFalse() {
        let path = "/usr/local/bin/mung"
        XCTAssertFalse(NotificationManager.isBundledExecutable(resolvedPath: path))
    }

    func testIsBundledExecutable_nestedAppBundle_returnsTrue() {
        let path = "/Users/dev/Custom.app/Contents/MacOS/tool"
        XCTAssertTrue(NotificationManager.isBundledExecutable(resolvedPath: path))
    }
}
