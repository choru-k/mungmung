import XCTest
@testable import MungMung

final class CLIParserTests: XCTestCase {

    // MARK: - Empty / Default

    func testEmptyArgs_returnsHelpSubcommand() {
        let inv = CLIParser.parse([])
        XCTAssertEqual(inv.subcommand, "help")
        XCTAssertTrue(inv.positionalArgs.isEmpty)
        XCTAssertTrue(inv.flags.isEmpty)
        XCTAssertTrue(inv.boolFlags.isEmpty)
        XCTAssertTrue(inv.arrayFlags.isEmpty)
    }

    // MARK: - Subcommand

    func testSingleSubcommand() {
        let inv = CLIParser.parse(["version"])
        XCTAssertEqual(inv.subcommand, "version")
        XCTAssertTrue(inv.positionalArgs.isEmpty)
        XCTAssertTrue(inv.flags.isEmpty)
        XCTAssertTrue(inv.boolFlags.isEmpty)
        XCTAssertTrue(inv.arrayFlags.isEmpty)
    }

    func testSubcommandIsLowercased() {
        let inv = CLIParser.parse(["ADD"])
        XCTAssertEqual(inv.subcommand, "add")
    }

    func testSubcommandMixedCase() {
        let inv = CLIParser.parse(["LiSt"])
        XCTAssertEqual(inv.subcommand, "list")
    }

    // MARK: - Valued Flags

    func testValuedFlags_titleAndMessage() {
        let inv = CLIParser.parse(["add", "--title", "Test", "--message", "Hello"])
        XCTAssertEqual(inv.subcommand, "add")
        XCTAssertEqual(inv.flags["--title"], "Test")
        XCTAssertEqual(inv.flags["--message"], "Hello")
        XCTAssertTrue(inv.positionalArgs.isEmpty)
        XCTAssertTrue(inv.boolFlags.isEmpty)
    }

    func testAllValuedFlags() {
        let inv = CLIParser.parse([
            "add",
            "--title", "T",
            "--message", "M",
            "--on-click", "open .",
            "--icon", "🔔",
            "--sound", "default"
        ])
        XCTAssertEqual(inv.flags.count, 5)
        XCTAssertEqual(inv.flags["--title"], "T")
        XCTAssertEqual(inv.flags["--message"], "M")
        XCTAssertEqual(inv.flags["--on-click"], "open .")
        XCTAssertEqual(inv.flags["--icon"], "🔔")
        XCTAssertEqual(inv.flags["--sound"], "default")
    }

    // MARK: - Array Flags

    func testSingleTag() {
        let inv = CLIParser.parse(["add", "--title", "T", "--message", "M", "--tag", "ci"])
        XCTAssertEqual(inv.arrayFlags["--tag"], ["ci"])
    }

    func testMultipleTags() {
        let inv = CLIParser.parse([
            "add", "--title", "T", "--message", "M",
            "--tag", "ci", "--tag", "deploy"
        ])
        XCTAssertEqual(inv.arrayFlags["--tag"], ["ci", "deploy"])
    }

    func testTagNotInValuedFlags() {
        let inv = CLIParser.parse(["add", "--title", "T", "--message", "M", "--tag", "ci"])
        XCTAssertNil(inv.flags["--tag"], "--tag should not appear in valued flags")
    }

    func testListWithTag() {
        let inv = CLIParser.parse(["list", "--json", "--tag", "ci"])
        XCTAssertEqual(inv.subcommand, "list")
        XCTAssertTrue(inv.boolFlags.contains("--json"))
        XCTAssertEqual(inv.arrayFlags["--tag"], ["ci"])
    }

    // MARK: - Boolean Flags

    func testBooleanFlag_json() {
        let inv = CLIParser.parse(["list", "--json"])
        XCTAssertEqual(inv.subcommand, "list")
        XCTAssertTrue(inv.boolFlags.contains("--json"))
        XCTAssertTrue(inv.flags.isEmpty)
    }

    func testUnknownFlagTreatedAsBoolean() {
        let inv = CLIParser.parse(["list", "--verbose"])
        XCTAssertTrue(inv.boolFlags.contains("--verbose"))
        XCTAssertTrue(inv.flags.isEmpty)
    }

    // MARK: - Positional Args

    func testPositionalArg() {
        let inv = CLIParser.parse(["done", "123_abc"])
        XCTAssertEqual(inv.subcommand, "done")
        XCTAssertEqual(inv.positionalArgs, ["123_abc"])
    }

    func testMultiplePositionalArgs() {
        let inv = CLIParser.parse(["done", "id1", "id2"])
        XCTAssertEqual(inv.positionalArgs, ["id1", "id2"])
    }

    // MARK: - Mixed

    func testMixed_positionalAndBoolFlag() {
        let inv = CLIParser.parse(["done", "123_abc", "--run"])
        XCTAssertEqual(inv.subcommand, "done")
        XCTAssertEqual(inv.positionalArgs, ["123_abc"])
        XCTAssertTrue(inv.boolFlags.contains("--run"))
    }

    func testMixed_valuedFlagAndBoolFlagAndArrayFlag() {
        let inv = CLIParser.parse(["list", "--json", "--tag", "ci"])
        XCTAssertEqual(inv.subcommand, "list")
        XCTAssertTrue(inv.boolFlags.contains("--json"))
        XCTAssertEqual(inv.arrayFlags["--tag"], ["ci"])
    }

    // MARK: - Edge Cases

    func testValuedFlagWithoutValue_atEndOfArgs() {
        let inv = CLIParser.parse(["add", "--title"])
        XCTAssertTrue(inv.boolFlags.contains("--title"))
        XCTAssertNil(inv.flags["--title"])
    }

    func testValuedFlagValueContainingSpaces() {
        let inv = CLIParser.parse(["add", "--title", "Hello World", "--message", "Line one"])
        XCTAssertEqual(inv.flags["--title"], "Hello World")
        XCTAssertEqual(inv.flags["--message"], "Line one")
    }

    func testArrayFlagWithoutValue_atEndOfArgs() {
        let inv = CLIParser.parse(["add", "--title", "T", "--message", "M", "--tag"])
        XCTAssertTrue(inv.boolFlags.contains("--tag"))
        XCTAssertTrue(inv.arrayFlags.isEmpty)
    }
}
