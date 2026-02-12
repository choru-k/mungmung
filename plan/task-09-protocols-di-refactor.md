# Task 9: Protocols & DI Refactor

## Overview

Create `NotificationSending` and `ShellExecuting` protocols to abstract system dependencies, conform existing types, and refactor `Commands` to return `Int32` exit codes with dependency injection via default parameters. This makes `Commands` fully unit-testable while keeping all existing call sites compiling unchanged.

## Scope
- **Files:** `Sources/MungMung/Services/Protocols.swift` (create), `Sources/MungMung/Services/NotificationManager.swift` (modify), `Sources/MungMung/Services/ShellHelper.swift` (modify), `Sources/MungMung/CLI/Commands.swift` (modify)
- **Effort:** ~1.5h
- **Depends on:** Tasks 4, 5, 7 (all implemented)
- **Blocks:** Tasks 10, 11, 12, 13

## Step 1: Define Verification

Since this is a refactoring task (no new behavior), the test is that the project still compiles and existing tests pass.

**Verification command:**
```bash
swift build 2>&1
```

**Expected output:** Build succeeds (exit 0).

## Step 2: Verify Current State

Run `swift build` to confirm the project builds before changes.

## Step 3: Implement

### 3a. Create `Protocols.swift`

**File:** `Sources/MungMung/Services/Protocols.swift` (create)

Two protocols that abstract the system dependencies used by `Commands`:

```swift
import Foundation

/// Abstracts notification operations for dependency injection in Commands.
protocol NotificationSending {
    @discardableResult func requestPermission() -> Bool
    func send(alert: Alert)
    func remove(alertID: String)
    func remove(alertIDs: [String])
}

/// Abstracts shell execution for dependency injection in Commands.
protocol ShellExecuting {
    func triggerSketchybar()
    func execute(command: String)
}
```

### 3b. Conform `NotificationManager` to `NotificationSending`

**File:** `Sources/MungMung/Services/NotificationManager.swift:10`

Change the class declaration from:
```swift
final class NotificationManager {
```
to:
```swift
final class NotificationManager: NotificationSending {
```

No other changes needed — all methods already match the protocol signatures.

### 3c. Add `ShellRunner` struct to `ShellHelper.swift`

**File:** `Sources/MungMung/Services/ShellHelper.swift` (append after `ShellHelper` enum)

Keep the existing `ShellHelper` enum unchanged (used by `AppDelegate`). Add a `ShellRunner` struct that conforms to `ShellExecuting` and delegates to the static methods:

```swift
/// Instance-based wrapper around ShellHelper for dependency injection.
struct ShellRunner: ShellExecuting {
    func triggerSketchybar() {
        ShellHelper.triggerSketchybar()
    }

    func execute(command: String) {
        ShellHelper.execute(command: command)
    }
}
```

### 3d. Refactor `Commands.swift`

**File:** `Sources/MungMung/CLI/Commands.swift`

Replace the entire `Commands` enum body. Key changes:
1. Remove `private static let store` and `private static let notifications`
2. Each method returns `Int32` exit code instead of calling `exit()`
3. Add default parameters for dependencies: `store`, `notifications`, `shell`
4. Add `output: (String) -> Void = { print($0) }` closure for capturing stdout
5. Add `errorOutput: (String) -> Void = { CLIParser.printError($0) }` where needed
6. Add `@discardableResult` to each method

```swift
import Foundation

/// All CLI command implementations.
///
/// Each method returns an Int32 exit code (0 = success, 1 = error).
/// Dependencies are injected via default parameters — existing call sites
/// compile unchanged, but tests can pass mocks.
enum Commands {

    // MARK: - add

    /// Create a new alert, save state, send notification, trigger sketchybar.
    @discardableResult
    static func add(
        title: String,
        message: String,
        onClick: String?,
        icon: String?,
        group: String?,
        sound: String?,
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        output: (String) -> Void = { print($0) },
        errorOutput: (String) -> Void = { CLIParser.printError($0) }
    ) -> Int32 {
        notifications.requestPermission()

        let alert = Alert(
            title: title,
            message: message,
            onClick: onClick,
            icon: icon,
            group: group,
            sound: sound
        )

        do {
            try store.save(alert)
        } catch {
            errorOutput("failed to save alert: \(error.localizedDescription)")
            return 1
        }

        notifications.send(alert: alert)
        shell.triggerSketchybar()

        output(alert.id)
        return 0
    }

    // MARK: - done

    /// Dismiss an alert: remove state file, remove notification, optionally run on_click.
    @discardableResult
    static func done(
        id: String,
        run: Bool,
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        errorOutput: (String) -> Void = { CLIParser.printError($0) }
    ) -> Int32 {
        guard let alert = store.remove(id: id) else {
            errorOutput("alert not found: \(id)")
            return 1
        }

        if run, let onClick = alert.onClick, !onClick.isEmpty {
            shell.execute(command: onClick)
        }

        notifications.remove(alertID: alert.id)
        shell.triggerSketchybar()

        return 0
    }

    // MARK: - list

    /// List pending alerts as human-readable table or JSON.
    @discardableResult
    static func list(
        json: Bool,
        group: String?,
        store: AlertStore = AlertStore(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let alerts = store.list(group: group)

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(alerts),
               let jsonString = String(data: data, encoding: .utf8) {
                output(jsonString)
            } else {
                output("[]")
            }
        } else {
            if alerts.isEmpty {
                output("No pending alerts.")
            } else {
                // Header
                output(String(format: "%-26s %-10s %-5s %-20s %s",
                    "ID", "GROUP", "ICON", "TITLE", "AGE"))

                for alert in alerts {
                    output(String(format: "%-26s %-10s %-5s %-20s %s",
                        alert.id,
                        alert.group ?? "-",
                        alert.icon ?? "-",
                        String(alert.title.prefix(20)),
                        alert.age))
                }
            }
        }

        return 0
    }

    // MARK: - count

    /// Print the number of pending alerts.
    @discardableResult
    static func count(
        group: String?,
        store: AlertStore = AlertStore(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        output("\(store.count(group: group))")
        return 0
    }

    // MARK: - clear

    /// Remove all alerts (or all in a group).
    @discardableResult
    static func clear(
        group: String?,
        store: AlertStore = AlertStore(),
        notifications: NotificationSending = NotificationManager(),
        shell: ShellExecuting = ShellRunner(),
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let removed = store.clear(group: group)
        let ids = removed.map { $0.id }

        notifications.remove(alertIDs: ids)
        shell.triggerSketchybar()

        output("Cleared \(removed.count) alert\(removed.count == 1 ? "" : "s").")
        return 0
    }

    // MARK: - version

    /// Print version string.
    @discardableResult
    static func version(
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
        output("mung \(version)")
        return 0
    }

    // MARK: - help

    /// Print usage information.
    @discardableResult
    static func help(
        output: (String) -> Void = { print($0) }
    ) -> Int32 {
        output("""
        Usage: mung <command> [options]

        Commands:
          add      Create alert and send notification
                   --title "..."       Alert title (required)
                   --message "..."     Alert message (required)
                   --on-click "cmd"    Command to run on notification click
                   --icon "\u{1F514}"         Icon emoji
                   --group "name"      Group name for filtering
                   --sound "default"   Notification sound

          done     Dismiss alert by ID
                   <id>                Alert ID (required)
                   --run               Execute on_click command

          list     List pending alerts
                   --json              Output as JSON
                   --group "name"      Filter by group

          count    Print number of pending alerts
                   --group "name"      Filter by group

          clear    Dismiss all alerts
                   --group "name"      Clear only this group

          version  Print version
          help     Show this help

        State directory: $MUNG_DIR (default: ~/.local/share/mung)
        """)
        return 0
    }
}
```

## Step 4: Verify Build

```bash
swift build 2>&1
```

**Expected output:** Build succeeds (exit 0). All existing code compiles because default parameters preserve API compatibility.

```bash
swift test 2>&1
```

**Expected output:** All 45 existing tests pass.

## Step 5: Commit

```bash
git add Sources/MungMung/Services/Protocols.swift Sources/MungMung/Services/NotificationManager.swift Sources/MungMung/Services/ShellHelper.swift Sources/MungMung/CLI/Commands.swift
git commit -m "refactor(commands): add protocols and DI for testability"
```

## Error Protocol

If any step fails:

1. **Strike 1:** Read the error message carefully. Fix the most likely cause. Re-run.
2. **Strike 2:** Re-read this task file and main.md. Try an alternative approach. Re-run.
3. **Strike 3:** STOP. Log the error in main.md's Log section. Do not proceed.

## Exit Criteria

- [ ] `swift build` compiles clean
- [ ] All 45 existing tests still pass
- [ ] `Protocols.swift` exists with `NotificationSending` and `ShellExecuting`
- [ ] `NotificationManager` conforms to `NotificationSending`
- [ ] `ShellRunner` struct conforms to `ShellExecuting`
- [ ] All 7 `Commands` methods return `Int32` and accept injected dependencies
- [ ] No `exit()` calls remain in `Commands.swift`
