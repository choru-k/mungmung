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

    // MARK: - canUseNotificationCenter

    func testCanUseNotificationCenter_bundleIdentifierPresent_returnsTrue() {
        let canUse = NotificationManager.canUseNotificationCenter(
            bundleIdentifier: "dev.choru.mungmung",
            executablePath: "/Users/dev/project/.build/debug/MungMung"
        )

        XCTAssertTrue(canUse)
    }

    func testCanUseNotificationCenter_bundleIdentifierMissingButAppBundlePath_returnsTrue() {
        let canUse = NotificationManager.canUseNotificationCenter(
            bundleIdentifier: nil,
            executablePath: "/Applications/MungMung.app/Contents/MacOS/MungMung"
        )

        XCTAssertTrue(canUse)
    }

    func testCanUseNotificationCenter_bundleIdentifierMissingAndNonBundlePath_returnsFalse() {
        let canUse = NotificationManager.canUseNotificationCenter(
            bundleIdentifier: nil,
            executablePath: "/Users/dev/project/.build/debug/MungMung"
        )

        XCTAssertFalse(canUse)
    }
}
