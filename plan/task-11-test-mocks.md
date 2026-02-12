# Task 11: Test Mocks

## Overview

Create mock implementations of `NotificationSending` and `ShellExecuting` protocols plus an `OutputCapture` helper for unit testing `Commands`. These mocks record all calls so tests can assert on behavior without touching real system services.

## Scope
- **Files:** `Tests/MungMungTests/Mocks.swift` (create)
- **Effort:** ~30m
- **Depends on:** Task 9 (protocols must exist)
- **Blocks:** Task 12

## Step 1: Write Test

Since mocks are test infrastructure (not application code), we verify they compile and the existing tests still pass.

**Verification command:**
```bash
swift test 2>&1
```

**Expected output:** All 45 existing tests pass, no compilation errors.

## Step 2: Verify Current State

Confirm `swift test` passes before adding the mock file.

## Step 3: Implement

**File:** `Tests/MungMungTests/Mocks.swift` (create)

```swift
import Foundation
@testable import MungMung

// MARK: - MockNotificationManager

/// Records all notification operations for test assertions.
final class MockNotificationManager: NotificationSending {
    var permissionRequested = false
    var permissionResult = true
    var sentAlerts: [Alert] = []
    var removedAlertIDs: [String] = []
    var removedAlertIDsBatch: [[String]] = []

    @discardableResult
    func requestPermission() -> Bool {
        permissionRequested = true
        return permissionResult
    }

    func send(alert: Alert) {
        sentAlerts.append(alert)
    }

    func remove(alertID: String) {
        removedAlertIDs.append(alertID)
    }

    func remove(alertIDs: [String]) {
        removedAlertIDsBatch.append(alertIDs)
    }
}

// MARK: - MockShellRunner

/// Records all shell operations for test assertions.
final class MockShellRunner: ShellExecuting {
    var triggerSketchybarCount = 0
    var executedCommands: [String] = []

    func triggerSketchybar() {
        triggerSketchybarCount += 1
    }

    func execute(command: String) {
        executedCommands.append(command)
    }
}

// MARK: - OutputCapture

/// Collects output strings via a closure for testing Commands output.
final class OutputCapture {
    var lines: [String] = []

    var capture: (String) -> Void {
        return { [weak self] text in
            self?.lines.append(text)
        }
    }

    /// All captured output joined with newlines.
    var text: String {
        lines.joined(separator: "\n")
    }
}
```

## Step 4: Verify

```bash
swift test 2>&1
```

**Expected output:** All 45 existing tests still pass. The new file compiles without errors.

## Step 5: Commit

```bash
git add Tests/MungMungTests/Mocks.swift
git commit -m "test(mocks): add MockNotificationManager, MockShellRunner, OutputCapture"
```

## Error Protocol

If any step fails:

1. **Strike 1:** Read the error message carefully. Fix the most likely cause. Re-run.
2. **Strike 2:** Re-read this task file and main.md. Try an alternative approach. Re-run.
3. **Strike 3:** STOP. Log the error in main.md's Log section. Do not proceed.

## Exit Criteria

- [ ] `Mocks.swift` exists in `Tests/MungMungTests/`
- [ ] `MockNotificationManager` conforms to `NotificationSending` and records calls
- [ ] `MockShellRunner` conforms to `ShellExecuting` and records calls
- [ ] `OutputCapture` collects strings via its `capture` closure
- [ ] All 45 existing tests still pass
