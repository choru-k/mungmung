# Task 3: CLI Argument Parser

## Background

mungmung's CLI (`mung`) has 7 subcommands with simple flag-based options. Rather than pulling in Apple's `ArgumentParser` package (which adds a dependency and build complexity), we use a hand-rolled parser. The CLI is simple enough — 7 subcommands, each with at most a few `--key value` flags.

The CLI interface (from SPEC.md):
```
mung add     --title "..." --message "..." [--on-click "cmd"] [--icon "🔔"] [--group "name"] [--sound "default"]
mung list    [--json] [--group "name"]
mung done    <id> [--run]
mung count   [--group "name"]
mung clear   [--group "name"]
mung version
mung help
```

## Dependencies

- **Task 1** (Project Setup) — Package.swift and directory structure must exist

## Files to Create

| File | Purpose |
|------|---------|
| `Sources/MungMung/CLI/CLIParser.swift` | Parse arguments, extract flags/values, route to subcommands |

## Implementation

### `Sources/MungMung/CLI/CLIParser.swift`

```swift
import Foundation

/// Parses `CommandLine.arguments` and routes to the appropriate subcommand handler.
///
/// Usage pattern:
/// ```
/// let args = Array(CommandLine.arguments.dropFirst()) // drop executable path
/// let parsed = CLIParser.parse(args)
/// CLIParser.route(parsed)
/// ```
///
/// Supports:
/// - Subcommand as first positional argument: `mung add`, `mung done`
/// - `--key value` flags: `--title "Hello"`, `--group claude`
/// - Boolean flags: `--json`, `--run`
/// - Positional arguments after subcommand: `mung done <id>`
enum CLIParser {

    /// Parsed CLI invocation.
    struct Invocation {
        let subcommand: String
        let positionalArgs: [String]    // args that aren't flags
        let flags: [String: String]     // --key value pairs
        let boolFlags: Set<String>      // --flag (no value)
    }

    /// Known flags that take a value (--key value).
    /// Everything else with `--` prefix is treated as a boolean flag.
    private static let valuedFlags: Set<String> = [
        "--title", "--message", "--on-click", "--icon", "--group", "--sound"
    ]

    /// Parse raw arguments into an Invocation.
    ///
    /// Arguments format: `<subcommand> [positional...] [--flag] [--key value]`
    ///
    /// Examples:
    /// - `["add", "--title", "Hello", "--message", "World"]`
    /// - `["done", "1738000000_a1b2c3d4", "--run"]`
    /// - `["list", "--json", "--group", "claude"]`
    static func parse(_ args: [String]) -> Invocation {
        guard let subcommand = args.first else {
            return Invocation(subcommand: "help", positionalArgs: [], flags: [:], boolFlags: [])
        }

        var positionalArgs: [String] = []
        var flags: [String: String] = [:]
        var boolFlags: Set<String> = []

        var i = 1  // skip subcommand
        while i < args.count {
            let arg = args[i]

            if arg.hasPrefix("--") {
                if valuedFlags.contains(arg), i + 1 < args.count {
                    // --key value pair
                    flags[arg] = args[i + 1]
                    i += 2
                } else if !valuedFlags.contains(arg) {
                    // Boolean flag (--json, --run)
                    boolFlags.insert(arg)
                    i += 1
                } else {
                    // Valued flag without value — treat as bool
                    boolFlags.insert(arg)
                    i += 1
                }
            } else {
                positionalArgs.append(arg)
                i += 1
            }
        }

        return Invocation(
            subcommand: subcommand.lowercased(),
            positionalArgs: positionalArgs,
            flags: flags,
            boolFlags: boolFlags
        )
    }

    /// Route a parsed invocation to the corresponding command handler.
    /// This function calls the Commands enum (Task 5) and exits.
    ///
    /// Note: The actual Commands implementations are in Task 5.
    /// This method will be updated when Commands are implemented.
    static func route(_ invocation: Invocation) {
        switch invocation.subcommand {
        case "add":
            guard let title = invocation.flags["--title"],
                  let message = invocation.flags["--message"] else {
                printError("add requires --title and --message")
                exit(1)
            }
            Commands.add(
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
            Commands.done(
                id: id,
                run: invocation.boolFlags.contains("--run")
            )

        case "list":
            Commands.list(
                json: invocation.boolFlags.contains("--json"),
                group: invocation.flags["--group"]
            )

        case "count":
            Commands.count(group: invocation.flags["--group"])

        case "clear":
            Commands.clear(group: invocation.flags["--group"])

        case "version":
            Commands.version()

        case "help", "-h", "--help":
            Commands.help()

        default:
            printError("Unknown command: \(invocation.subcommand)")
            Commands.help()
            exit(1)
        }
    }

    /// Print an error message to stderr.
    static func printError(_ message: String) {
        FileHandle.standardError.write(Data("mung: \(message)\n".utf8))
    }
}
```

## Verification

1. **Build compiles:**
   ```bash
   swift build
   ```

2. **Test parsing logic manually** (temporary test in main):
   ```swift
   let test1 = CLIParser.parse(["add", "--title", "Test", "--message", "Hello", "--group", "ci"])
   assert(test1.subcommand == "add")
   assert(test1.flags["--title"] == "Test")
   assert(test1.flags["--message"] == "Hello")
   assert(test1.flags["--group"] == "ci")

   let test2 = CLIParser.parse(["done", "123_abc", "--run"])
   assert(test2.subcommand == "done")
   assert(test2.positionalArgs == ["123_abc"])
   assert(test2.boolFlags.contains("--run"))

   let test3 = CLIParser.parse(["list", "--json"])
   assert(test3.subcommand == "list")
   assert(test3.boolFlags.contains("--json"))
   ```

3. **Edge cases:**
   - `mung` with no args → routes to `help`
   - `mung add` without `--title` → prints error, exits 1
   - `mung unknown` → prints error + help, exits 1
   - `mung --help` → routes to help

## Architecture Context

The CLI parser is the entry point for all user interactions:

```
User runs: mung add --title "Build" --message "Done" --on-click "open https://github.com"

CommandLine.arguments = ["/path/to/MungMung", "add", "--title", "Build", "--message", "Done", "--on-click", "open https://github.com"]

CLIParser.parse(args) → Invocation {
    subcommand: "add",
    positionalArgs: [],
    flags: ["--title": "Build", "--message": "Done", "--on-click": "open https://github.com"],
    boolFlags: []
}

CLIParser.route(invocation) → Commands.add(title: "Build", message: "Done", onClick: "open https://github.com", ...)
```

The parser doesn't do any business logic — it just extracts structured data from raw arguments and delegates to `Commands` (Task 5). The `route()` method validates required parameters for each subcommand.

Full CLI interface:
```
mung add     --title "..." --message "..." [--on-click "cmd"] [--icon "🔔"] [--group "name"] [--sound "default"]
mung list    [--json] [--group "name"]
mung done    <id> [--run]
mung count   [--group "name"]
mung clear   [--group "name"]
mung version
mung help
```
