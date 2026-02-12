import XCTest
import Foundation
@testable import MungMung

@MainActor
final class AppSettingsTests: XCTestCase {

    var suiteName: String!
    var defaults: UserDefaults!
    var settings: AppSettings!

    override func setUp() {
        super.setUp()
        suiteName = "mung-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = AppSettings(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultPollingInterval() {
        XCTAssertEqual(settings.pollingInterval, 2.0)
    }

    func testDefaultSoundEnabled() {
        XCTAssertTrue(settings.soundEnabled)
    }

    // MARK: - Persistence

    func testPollingInterval_persists() {
        settings.pollingInterval = 5.0

        let settings2 = AppSettings(defaults: defaults)
        XCTAssertEqual(settings2.pollingInterval, 5.0)
    }

    func testSoundEnabled_persists() {
        settings.soundEnabled = false

        let settings2 = AppSettings(defaults: defaults)
        XCTAssertFalse(settings2.soundEnabled)
    }

    // MARK: - Notification

    func testPollingInterval_postsNotification() {
        let expectation = expectation(description: "pollingIntervalDidChange")

        let observer = NotificationCenter.default.addObserver(
            forName: .pollingIntervalDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        settings.pollingInterval = 10.0

        wait(for: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
