import AppKit
import ApplicationServices
import Foundation

private let defaultGhosttyBundleID = "com.mitchellh.ghostty"

private enum MatchMode: String {
    case exact
    case prefix
    case contains
    case regex
    case glob

    static func parse(_ raw: String?) -> MatchMode? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return MatchMode(rawValue: normalized)
    }
}

private struct Config {
    let targetSelector: String
    let matchMode: MatchMode
    let bundleIdentifier: String
    let retries: Int
    let retryDelayMilliseconds: useconds_t
    let debug: Bool
}

private struct Matcher {
    private let target: String
    private let mode: MatchMode
    private let regex: NSRegularExpression?

    init(target: String, mode: MatchMode) throws {
        self.target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode

        switch mode {
        case .regex:
            self.regex = try NSRegularExpression(
                pattern: self.target,
                options: [.caseInsensitive]
            )
        case .glob:
            let pattern = Self.globToRegex(self.target)
            self.regex = try NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        default:
            self.regex = nil
        }
    }

    func matches(_ rawCandidate: String) -> Bool {
        let candidate = rawCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }

        switch mode {
        case .exact:
            return candidate.caseInsensitiveCompare(target) == .orderedSame
        case .prefix:
            return candidate.lowercased().hasPrefix(target.lowercased())
        case .contains:
            return candidate.range(of: target, options: [.caseInsensitive]) != nil
        case .regex, .glob:
            guard let regex else { return false }
            let range = NSRange(location: 0, length: candidate.utf16.count)
            return regex.firstMatch(in: candidate, options: [], range: range) != nil
        }
    }

    private static func globToRegex(_ glob: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: glob)
        let wildcard = escaped
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")

        return "^\(wildcard)$"
    }
}

private enum ParseError: Error, CustomStringConvertible {
    case usage(String)
    case help

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .help:
            return ""
        }
    }
}

private enum FocusError: Error, CustomStringConvertible {
    case accessibilityPermissionMissing
    case appNotRunning(String)
    case selectorNotFound(String)
    case selectorNotActionable(String)
    case invalidRegex(String)

    var description: String {
        switch self {
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required. Enable terminal/app access at System Settings > Privacy & Security > Accessibility."
        case .appNotRunning(let bundleID):
            return "No running app found for bundle identifier '\(bundleID)'."
        case .selectorNotFound(let selector):
            return "No Ghostty AX element matched selector '\(selector)'."
        case .selectorNotActionable(let selector):
            return "Found matching AX element(s) for selector '\(selector)', but none accepted AXPress/AXSelected."
        case .invalidRegex(let message):
            return "Invalid selector regex: \(message)"
        }
    }
}

private func printUsage() {
    print("""
    Usage: MungGhosttyFocus --target <selector> [options]

    Options:
      --target <selector>         Ghostty AX selector text (or use env fallback)
      --match <mode>              exact | prefix | contains | regex | glob
      --bundle-id <bundle-id>     App bundle identifier (default: com.mitchellh.ghostty)
      --retry <count>             Retry count after first attempt (default: 1)
      --retry-delay-ms <ms>       Delay between attempts in milliseconds (default: 120)
      --debug                     Print AX traversal diagnostics to stderr
      --help                      Show this help

    Env fallback:
      MUNG_GHOSTTY_TARGET / PI_MUNG_GHOSTTY_SELECTOR
      MUNG_GHOSTTY_MATCH / PI_MUNG_GHOSTTY_SELECTOR_MODE
      MUNG_GHOSTTY_BUNDLE_ID
      MUNG_GHOSTTY_RETRIES
      MUNG_GHOSTTY_RETRY_DELAY_MS
      MUNG_GHOSTTY_DEBUG
    """)
}

private func normalized(_ raw: String?) -> String? {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }

    return trimmed
}

private func parseBool(_ raw: String?) -> Bool {
    guard let normalized = normalized(raw)?.lowercased() else { return false }
    return normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on"
}

private func parseInt(_ raw: String?) -> Int? {
    guard let normalized = normalized(raw) else { return nil }
    return Int(normalized)
}

private func parseConfig(arguments: [String], environment: [String: String]) throws -> Config {
    var target: String?
    var match: String?
    var bundleIdentifier: String?
    var retries: Int?
    var retryDelayMilliseconds: Int?
    var debug = false

    var index = 0
    while index < arguments.count {
        let argument = arguments[index]

        switch argument {
        case "--help", "-h":
            throw ParseError.help

        case "--target":
            guard index + 1 < arguments.count else {
                throw ParseError.usage("--target requires a value")
            }
            target = arguments[index + 1]
            index += 2

        case "--match":
            guard index + 1 < arguments.count else {
                throw ParseError.usage("--match requires a value")
            }
            match = arguments[index + 1]
            index += 2

        case "--bundle-id":
            guard index + 1 < arguments.count else {
                throw ParseError.usage("--bundle-id requires a value")
            }
            bundleIdentifier = arguments[index + 1]
            index += 2

        case "--retry":
            guard index + 1 < arguments.count else {
                throw ParseError.usage("--retry requires a value")
            }
            retries = Int(arguments[index + 1])
            index += 2

        case "--retry-delay-ms":
            guard index + 1 < arguments.count else {
                throw ParseError.usage("--retry-delay-ms requires a value")
            }
            retryDelayMilliseconds = Int(arguments[index + 1])
            index += 2

        case "--debug":
            debug = true
            index += 1

        default:
            throw ParseError.usage("Unknown argument: \(argument)")
        }
    }

    let resolvedTarget = normalized(target)
        ?? normalized(environment["MUNG_GHOSTTY_TARGET"])
        ?? normalized(environment["PI_MUNG_GHOSTTY_SELECTOR"])

    guard let resolvedTarget else {
        throw ParseError.usage("Missing selector. Provide --target or set MUNG_GHOSTTY_TARGET.")
    }

    let matchRaw = normalized(match)
        ?? normalized(environment["MUNG_GHOSTTY_MATCH"])
        ?? normalized(environment["PI_MUNG_GHOSTTY_SELECTOR_MODE"])

    let matchMode: MatchMode
    if let matchRaw {
        guard let parsedMode = MatchMode.parse(matchRaw) else {
            throw ParseError.usage("Invalid --match value '\(matchRaw)'. Expected exact|prefix|contains|regex|glob.")
        }
        matchMode = parsedMode
    } else if resolvedTarget.contains("*") || resolvedTarget.contains("?") {
        matchMode = .glob
    } else {
        matchMode = .exact
    }

    let resolvedBundleID = normalized(bundleIdentifier)
        ?? normalized(environment["MUNG_GHOSTTY_BUNDLE_ID"])
        ?? defaultGhosttyBundleID

    let resolvedRetries = max(0, min(5, retries
        ?? parseInt(environment["MUNG_GHOSTTY_RETRIES"])
        ?? 1))

    let resolvedRetryDelay = max(0, min(2000, retryDelayMilliseconds
        ?? parseInt(environment["MUNG_GHOSTTY_RETRY_DELAY_MS"])
        ?? 120))

    let resolvedDebug = debug || parseBool(environment["MUNG_GHOSTTY_DEBUG"])

    return Config(
        targetSelector: resolvedTarget,
        matchMode: matchMode,
        bundleIdentifier: resolvedBundleID,
        retries: resolvedRetries,
        retryDelayMilliseconds: useconds_t(resolvedRetryDelay),
        debug: resolvedDebug
    )
}

private func stderr(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

private func debugLog(_ config: Config, _ message: String) {
    guard config.debug else { return }
    stderr("MungGhosttyFocus: \(message)")
}

private func copyAttributeValue(_ element: AXUIElement, attribute: String) -> AnyObject? {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard status == .success, let value else { return nil }
    return value as AnyObject
}

private func copyAttributeNames(_ element: AXUIElement) -> [String] {
    var namesRef: CFArray?
    let status = AXUIElementCopyAttributeNames(element, &namesRef)
    guard status == .success, let namesRef else { return [] }
    return namesRef as? [String] ?? []
}

private func copyStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
    guard let value = copyAttributeValue(element, attribute: attribute) else { return nil }

    if let stringValue = value as? String {
        return stringValue
    }

    if let attributedValue = value as? NSAttributedString {
        return attributedValue.string
    }

    return nil
}

private func extractElements(_ value: AnyObject) -> [AXUIElement] {
    let elementTypeID = AXUIElementGetTypeID()
    let valueTypeID = CFGetTypeID(value)

    if valueTypeID == elementTypeID {
        return [unsafeBitCast(value, to: AXUIElement.self)]
    }

    guard valueTypeID == CFArrayGetTypeID(), let array = value as? NSArray else {
        return []
    }

    var elements: [AXUIElement] = []
    for item in array {
        let object = item as AnyObject
        if CFGetTypeID(object) == elementTypeID {
            elements.append(unsafeBitCast(object, to: AXUIElement.self))
        }
    }

    return elements
}

private func role(of element: AXUIElement) -> String? {
    copyStringAttribute(element, attribute: kAXRoleAttribute as String)
}

private func titleCandidates(of element: AXUIElement) -> [String] {
    let attributes = [
        kAXTitleAttribute as String,
        kAXDescriptionAttribute as String,
        kAXValueAttribute as String,
        kAXHelpAttribute as String,
        "AXIdentifier",
        "AXLabel"
    ]

    return attributes.compactMap { copyStringAttribute(element, attribute: $0) }
}

private func collectMatchingElements(
    roots: [AXUIElement],
    matcher: Matcher,
    config: Config
) -> [AXUIElement] {
    var queue = roots
    var index = 0
    var visited = Set<UInt>()
    var matches: [AXUIElement] = []
    let maxNodes = 8_000

    while index < queue.count, visited.count < maxNodes {
        let element = queue[index]
        index += 1

        let hash = CFHash(element)
        if visited.contains(hash) { continue }
        visited.insert(hash)

        let candidates = titleCandidates(of: element)
        if candidates.contains(where: { matcher.matches($0) }) {
            matches.append(element)
        }

        for attribute in copyAttributeNames(element) {
            if attribute == (kAXParentAttribute as String) { continue }
            guard let value = copyAttributeValue(element, attribute: attribute) else { continue }
            queue.append(contentsOf: extractElements(value))
        }
    }

    debugLog(config, "visited_nodes=\(visited.count) matches=\(matches.count)")
    return matches
}

private func supportsAction(_ element: AXUIElement, action: String) -> Bool {
    var actionsRef: CFArray?
    let status = AXUIElementCopyActionNames(element, &actionsRef)
    guard status == .success, let actionsRef else { return false }

    let actions = actionsRef as? [String] ?? []
    return actions.contains(action)
}

private func parent(of element: AXUIElement) -> AXUIElement? {
    guard let value = copyAttributeValue(element, attribute: kAXParentAttribute as String) else {
        return nil
    }

    return extractElements(value).first
}

private func raiseOwningWindow(of element: AXUIElement) {
    var current: AXUIElement? = element

    for _ in 0..<16 {
        guard let node = current else { return }

        if role(of: node) == (kAXWindowRole as String) {
            if supportsAction(node, action: kAXRaiseAction as String) {
                _ = AXUIElementPerformAction(node, kAXRaiseAction as CFString)
            }
            return
        }

        current = parent(of: node)
    }
}

private func activateElement(_ element: AXUIElement, app: NSRunningApplication) -> Bool {
    var current: AXUIElement? = element

    for _ in 0..<16 {
        guard let node = current else { break }

        if supportsAction(node, action: kAXPressAction as String) {
            let result = AXUIElementPerformAction(node, kAXPressAction as CFString)
            if result == .success {
                raiseOwningWindow(of: node)
                _ = app.activate(options: [])
                return true
            }
        }

        let selectedResult = AXUIElementSetAttributeValue(
            node,
            kAXSelectedAttribute as CFString,
            kCFBooleanTrue
        )

        if selectedResult == .success {
            raiseOwningWindow(of: node)
            _ = app.activate(options: [])
            return true
        }

        current = parent(of: node)
    }

    return false
}

private func runningGhosttyApp(bundleIdentifier: String) -> NSRunningApplication? {
    NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier)
        .first(where: { !$0.isTerminated })
}

private func focusOnce(config: Config) throws {
    guard AXIsProcessTrusted() else {
        throw FocusError.accessibilityPermissionMissing
    }

    guard let app = runningGhosttyApp(bundleIdentifier: config.bundleIdentifier) else {
        throw FocusError.appNotRunning(config.bundleIdentifier)
    }

    let matcher: Matcher
    do {
        matcher = try Matcher(target: config.targetSelector, mode: config.matchMode)
    } catch {
        throw FocusError.invalidRegex(error.localizedDescription)
    }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var roots: [AXUIElement] = []

    if let windowsValue = copyAttributeValue(axApp, attribute: kAXWindowsAttribute as String) {
        roots = extractElements(windowsValue)
    }

    if roots.isEmpty,
       let childrenValue = copyAttributeValue(axApp, attribute: kAXChildrenAttribute as String) {
        roots = extractElements(childrenValue)
    }

    if roots.isEmpty {
        roots = [axApp]
    }

    let matches = collectMatchingElements(roots: roots, matcher: matcher, config: config)
    guard !matches.isEmpty else {
        throw FocusError.selectorNotFound(config.targetSelector)
    }

    for match in matches {
        if activateElement(match, app: app) {
            debugLog(config, "focused selector=\(config.targetSelector)")
            return
        }
    }

    throw FocusError.selectorNotActionable(config.targetSelector)
}

private func run(config: Config) -> Int32 {
    let attempts = config.retries + 1
    var lastError: Error?

    for attempt in 1...attempts {
        do {
            try focusOnce(config: config)
            return 0
        } catch {
            lastError = error
            debugLog(config, "attempt=\(attempt)/\(attempts) failed: \(error)")

            if attempt < attempts {
                usleep(config.retryDelayMilliseconds * 1_000)
            }
        }
    }

    if let focusError = lastError as? FocusError {
        stderr(focusError.description)
    } else if let lastError {
        stderr(lastError.localizedDescription)
    } else {
        stderr("Unknown Ghostty AX focus error")
    }

    return 1
}

private func main() -> Int32 {
    let args = Array(CommandLine.arguments.dropFirst())

    do {
        let config = try parseConfig(arguments: args, environment: ProcessInfo.processInfo.environment)
        return run(config: config)
    } catch let error as ParseError {
        switch error {
        case .help:
            printUsage()
            return 0
        case .usage(let message):
            if !message.isEmpty {
                stderr(message)
            }
            printUsage()
            return 2
        }
    } catch {
        stderr(error.localizedDescription)
        return 1
    }
}

exit(main())
