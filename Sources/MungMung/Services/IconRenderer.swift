import AppKit
import Foundation

/// Renders icons from emoji, SF Symbols, or image file paths to NSImage.
///
/// Used by `IconView` (SwiftUI popup) and `NotificationManager` (notification attachments).
enum IconRenderer {

    /// Auto-detected icon type.
    enum IconType: Equatable {
        case emoji(String)
        case sfSymbol(String)
        case imageFile(String)
    }

    // MARK: - Detection

    /// Detect icon type from a raw string.
    ///
    /// Detection order:
    /// 1. File path — starts with `/` or `~`
    /// 2. SF Symbol — `NSImage(systemSymbolName:)` returns non-nil
    /// 3. Emoji — fallback
    static func detect(_ icon: String) -> IconType {
        let trimmed = icon.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .emoji(trimmed) }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return .imageFile(trimmed)
        }

        if NSImage(systemSymbolName: trimmed, accessibilityDescription: nil) != nil {
            return .sfSymbol(trimmed)
        }

        return .emoji(trimmed)
    }

    // MARK: - Render to NSImage

    /// Render any icon type to an NSImage.
    ///
    /// Returns `nil` if the icon cannot be rendered (e.g. missing file).
    static func renderToImage(_ icon: String, pointSize: CGFloat = 64) -> NSImage? {
        switch detect(icon) {
        case .emoji(let text):
            return renderEmoji(text, pointSize: pointSize)
        case .sfSymbol(let name):
            return renderSFSymbol(name, pointSize: pointSize)
        case .imageFile(let path):
            return renderImageFile(path, pointSize: pointSize)
        }
    }

    // MARK: - Temp PNG

    /// Write an NSImage to a temporary PNG file.
    ///
    /// Returns the file URL on success, `nil` on failure.
    /// Caller is responsible for cleaning up the file.
    static func writeTempPNG(_ image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        do {
            try pngData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private static func renderSFSymbol(_ name: String, pointSize: CGFloat) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        return symbol.withSymbolConfiguration(config)
    }

    private static func renderImageFile(_ path: String, pointSize: CGFloat) -> NSImage? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath),
              let image = NSImage(contentsOfFile: expandedPath) else {
            return nil
        }
        let size = NSSize(width: pointSize, height: pointSize)
        image.size = size
        return image
    }

    private static func renderEmoji(_ text: String, pointSize: CGFloat) -> NSImage? {
        guard !text.isEmpty else { return nil }

        let fontSize = pointSize * 0.8
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let size = NSSize(width: max(textSize.width, pointSize), height: max(textSize.height, pointSize))

        let image = NSImage(size: size, flipped: false) { rect in
            let origin = NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2
            )
            (text as NSString).draw(at: origin, withAttributes: attrs)
            return true
        }

        return image
    }
}
