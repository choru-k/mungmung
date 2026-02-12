# Task 10: Update Call Sites & Makefile

## Overview

Update `CLIParser.route()` and `MungMungApp.main()` to handle the new `Int32` return values from `Commands`, and update the Makefile `test` target to build before running tests (needed for integration tests).

## Scope
- **Files:** `Sources/MungMung/CLI/CLIParser.swift` (modify), `Sources/MungMung/MungMungApp.swift` (modify), `Makefile` (modify)
- **Effort:** ~30m
- **Depends on:** Task 9
- **Blocks:** Tasks 12, 13

## Step 1: Define Verification

**Verification command:**
```bash
swift build && swift test
```

**Expected output:** Build succeeds, all 45 existing tests pass.

## Step 2: Verify Current State

After Task 9, `swift build` should already pass. Verify before making call-site changes.

## Step 3: Implement

### 3a. Update `CLIParser.route()`

**File:** `Sources/MungMung/CLI/CLIParser.swift:86-136`

Replace the `route(_:)` method. Key change: capture the `Int32` return value from each `Commands` call, then call `exit(code)` at the end.

```swift
    /// Route a parsed invocation to the corresponding command handler.
    /// Calls the appropriate Commands method, then exits with the returned code.
    static func route(_ invocation: Invocation) {
        let code: Int32

        switch invocation.subcommand {
        case "add":
            guard let title = invocation.flags["--title"],
                  let message = invocation.flags["--message"] else {
                printError("add requires --title and --message")
                exit(1)
            }
            code = Commands.add(
                title: title,
                message: message,
                onClick: invocation.flags["--on-click"],
                icon: invocation.flags["--icon"],
                group: invocation.flags["--group"],
                sound: invocation.flags["--sound"]
            )

        case "done":
            guard let id = invocation.positionalArgs.first else {
                printError("done requires an alert ID")
                exit(1)
            }
            code = Commands.done(
                id: id,
                run: invocation.boolFlags.contains("--run")
            )

        case "list":
            code = Commands.list(
                json: invocation.boolFlags.contains("--json"),
                group: invocation.flags["--group"]
            )

        case "count":
            code = Commands.count(group: invocation.flags["--group"])

        case "clear":
            code = Commands.clear(group: invocation.flags["--group"])

        case "version":
            code = Commands.version()

        case "help", "-h", "--help":
            code = Commands.help()

        default:
            printError("Unknown command: \(invocation.subcommand)")
            _ = Commands.help()
            exit(1)
        }

        exit(code)
    }
```

### 3b. Update `MungMungApp.swift`

**File:** `Sources/MungMung/MungMungApp.swift:32`

Change:
```swift
                Commands.help()
```
to:
```swift
                _ = Commands.help()
```

This suppresses the unused return value warning since `exit(0)` follows on the next line.

### 3c. Update Makefile `test` target

**File:** `Makefile:27-29`

Change:
```makefile
test:
	@echo "Running tests..."
	swift test
```
to:
```makefile
test:
	@echo "Running tests..."
	swift build && swift test
```

This ensures the debug binary is built before integration tests (Task 13) try to spawn it.

## Step 4: Verify Changes

```bash
swift build && swift test
```

**Expected output:** Build succeeds, all 45 existing tests pass.

**Additional verification:**
```bash
.build/debug/MungMung help
.build/debug/MungMung version
```

Both should produce expected output and exit 0.

## Step 5: Commit

```bash
git add Sources/MungMung/CLI/CLIParser.swift Sources/MungMung/MungMungApp.swift Makefile
git commit -m "refactor(cli): update call sites for Commands return codes"
```

## Error Protocol

If any step fails:

1. **Strike 1:** Read the error message carefully. Fix the most likely cause. Re-run.
2. **Strike 2:** Re-read this task file and main.md. Try an alternative approach. Re-run.
3. **Strike 3:** STOP. Log the error in main.md's Log section. Do not proceed.

## Exit Criteria

- [ ] `swift build` compiles clean
- [ ] All 45 existing tests still pass
- [ ] `CLIParser.route()` captures return codes and calls `exit(code)`
- [ ] No unused result warning for `Commands.help()` in MungMungApp
- [ ] Makefile `test` target runs `swift build && swift test`
- [ ] `mung help` and `mung version` work correctly via the binary
