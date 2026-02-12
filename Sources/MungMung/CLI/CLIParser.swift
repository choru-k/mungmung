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

    /// Print an error message to stderr.
    static func printError(_ message: String) {
        FileHandle.standardError.write(Data("mung: \(message)\n".utf8))
    }
}
