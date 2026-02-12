import XCTest
import Foundation
@testable import MungMung

@MainActor
final class AlertViewModelTests: XCTestCase {

    var tempDir: URL!
    var store: AlertStore!
    var mockNotifications: MockNotificationManager!
    var mockShell: MockShellRunner!
    var vm: AlertViewModel!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mung-test-\(UUID().uuidString)")
        store = AlertStore(baseDir: tempDir)
        mockNotifications = MockNotificationManager()
        mockShell = MockShellRunner()
        vm = AlertViewModel(
            store: store,
            notifications: mockNotifications,
            shell: mockShell
        )
    }

    override func tearDown() {
        vm.stopPolling()
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_empty() {
        XCTAssertEqual(vm.alerts, [])
    }

    // MARK: - startPolling

    func testStartPolling_loadsAlerts() throws {
        let alert = Alert(title: "Test", message: "Hello")
        try store.save(alert)

        vm.startPolling()

        XCTAssertEqual(vm.alerts.count, 1)
        XCTAssertEqual(vm.alerts.first?.title, "Test")
    }

    // MARK: - dismiss

    func testDismiss_removesFromStore() throws {
        let alert = Alert(title: "T", message: "M")
        try store.save(alert)
        vm.startPolling()

        vm.dismiss(alert)

        XCTAssertNil(store.load(id: alert.id))
    }

    func testDismiss_removesNotification() throws {
        let alert = Alert(title: "T", message: "M")
        try store.save(alert)
        vm.startPolling()

        vm.dismiss(alert)

        XCTAssertEqual(mockNotifications.removedAlertIDs, [alert.id])
    }

    func testDismiss_triggersSketchybar() throws {
        let alert = Alert(title: "T", message: "M")
        try store.save(alert)
        vm.startPolling()

        vm.dismiss(alert)

        XCTAssertEqual(mockShell.triggerSketchybarCount, 1)
    }

    func testDismiss_refreshesAlerts() throws {
        let alert = Alert(title: "T", message: "M")
        try store.save(alert)
        vm.startPolling()
        XCTAssertEqual(vm.alerts.count, 1)

        vm.dismiss(alert)

        XCTAssertEqual(vm.alerts.count, 0)
    }

    // MARK: - clearAll

    func testClearAll_removesAllFromStore() throws {
        try store.save(Alert(title: "A", message: "1"))
        try store.save(Alert(title: "B", message: "2"))
        vm.startPolling()
        XCTAssertEqual(vm.alerts.count, 2)

        vm.clearAll()

        XCTAssertEqual(store.list().count, 0)
    }

    func testClearAll_removesNotifications() throws {
        let a1 = Alert(title: "A", message: "1")
        let a2 = Alert(title: "B", message: "2")
        try store.save(a1)
        try store.save(a2)
        vm.startPolling()

        vm.clearAll()

        XCTAssertEqual(mockNotifications.removedAlertIDsBatch.count, 1)
        let removedIDs = Set(mockNotifications.removedAlertIDsBatch[0])
        XCTAssertTrue(removedIDs.contains(a1.id))
        XCTAssertTrue(removedIDs.contains(a2.id))
    }

    func testClearAll_triggersSketchybar() throws {
        try store.save(Alert(title: "T", message: "M"))
        vm.startPolling()

        vm.clearAll()

        XCTAssertEqual(mockShell.triggerSketchybarCount, 1)
    }

    func testClearAll_refreshesAlerts() throws {
        try store.save(Alert(title: "A", message: "1"))
        try store.save(Alert(title: "B", message: "2"))
        vm.startPolling()

        vm.clearAll()

        XCTAssertEqual(vm.alerts.count, 0)
    }

    // MARK: - Notification Observer

    func testNotificationPost_reloadsAlerts() throws {
        vm.startPolling()
        XCTAssertEqual(vm.alerts.count, 0)

        try store.save(Alert(title: "New", message: "Alert"))
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)

        // The observer dispatches via Task { @MainActor }, so give the run loop a tick
        let expectation = expectation(description: "reload")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(vm.alerts.count, 1)
        XCTAssertEqual(vm.alerts.first?.title, "New")
    }

    // MARK: - stopPolling

    func testStopPolling_cleansUp() throws {
        vm.startPolling()
        vm.stopPolling()

        // After stopping, saving a new alert and posting notification should NOT reload
        try store.save(Alert(title: "Ghost", message: "Should not appear"))
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)

        let expectation = expectation(description: "no reload")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(vm.alerts.count, 0)
    }
}
