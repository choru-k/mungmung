@testable import MungMung
import XCTest

final class IconRendererTests: XCTestCase {

    // MARK: - detect

    func testDetect_emoji_returnsEmoji() {
        XCTAssertEqual(IconRenderer.detect("🤖"), .emoji("🤖"))
    }

    func testDetect_sfSymbol_returnsSFSymbol() {
        XCTAssertEqual(IconRenderer.detect("bell.fill"), .sfSymbol("bell.fill"))
    }

    func testDetect_absolutePath_returnsImageFile() {
        XCTAssertEqual(IconRenderer.detect("/path/to/icon.png"), .imageFile("/path/to/icon.png"))
    }

    func testDetect_tildePath_returnsImageFile() {
        XCTAssertEqual(IconRenderer.detect("~/Desktop/icon.png"), .imageFile("~/Desktop/icon.png"))
    }

    func testDetect_invalidSFSymbolName_returnsEmoji() {
        XCTAssertEqual(IconRenderer.detect("not_a_real_sf_symbol_xyz"), .emoji("not_a_real_sf_symbol_xyz"))
    }

    func testDetect_plainText_returnsEmoji() {
        XCTAssertEqual(IconRenderer.detect("hello"), .emoji("hello"))
    }

    func testDetect_whitespace_trimmed() {
        XCTAssertEqual(IconRenderer.detect("  bell.fill  "), .sfSymbol("bell.fill"))
    }

    func testDetect_whitespaceOnlyPath_trimmed() {
        XCTAssertEqual(IconRenderer.detect("  /path/to/icon.png  "), .imageFile("/path/to/icon.png"))
    }

    // MARK: - renderToImage

    func testRenderToImage_emoji_returnsNonNil() {
        let image = IconRenderer.renderToImage("🤖")
        XCTAssertNotNil(image)
    }

    func testRenderToImage_sfSymbol_returnsNonNil() {
        let image = IconRenderer.renderToImage("bell.fill")
        XCTAssertNotNil(image)
    }

    func testRenderToImage_missingFile_returnsNil() {
        let image = IconRenderer.renderToImage("/nonexistent/path/icon.png")
        XCTAssertNil(image)
    }

    func testRenderToImage_emptyString_returnsNil() {
        let image = IconRenderer.renderToImage("")
        XCTAssertNil(image)
    }

    // MARK: - writeTempPNG

    func testWriteTempPNG_createsFile() throws {
        let image = try XCTUnwrap(IconRenderer.renderToImage("🤖"))
        let url = try XCTUnwrap(IconRenderer.writeTempPNG(image))
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testWriteTempPNG_hasPNGExtension() throws {
        let image = try XCTUnwrap(IconRenderer.renderToImage("🤖"))
        let url = try XCTUnwrap(IconRenderer.writeTempPNG(image))
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "png")
    }

    func testWriteTempPNG_hasPNGMagicBytes() throws {
        let image = try XCTUnwrap(IconRenderer.renderToImage("🤖"))
        let url = try XCTUnwrap(IconRenderer.writeTempPNG(image))
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        // PNG magic bytes: 89 50 4E 47
        XCTAssertGreaterThanOrEqual(data.count, 4)
        XCTAssertEqual(data[0], 0x89)
        XCTAssertEqual(data[1], 0x50)
        XCTAssertEqual(data[2], 0x4E)
        XCTAssertEqual(data[3], 0x47)
    }
}
