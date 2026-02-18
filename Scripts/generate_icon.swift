#!/usr/bin/env swift

// generate_icon.swift
// Generates AppIcon.icns with Apple's squircle mask baked in.
//
// Uses SwiftUI's RoundedRectangle(style: .continuous) — Apple's exact
// continuous-curvature superellipse — to create a pixel-perfect mask.
//
// Usage: swift Scripts/generate_icon.swift [source_png] [output_dir]
//   source_png defaults to Resources/AppIcon-source.png
//   output_dir  defaults to Resources/

import AppKit
import SwiftUI

// ============================================================================
// Configuration - Apple's macOS icon spec for 1024x1024 canvas
// ============================================================================
let canvasSize: CGFloat    = 1024
let squircleInset: CGFloat = 100   // 100px gutter on each side → 824x824 visible area
let cornerRadius: CGFloat  = 185   // Apple's spec for the 824px squircle

// ============================================================================
// Arguments
// ============================================================================
let args = CommandLine.arguments
let scriptDir = URL(fileURLWithPath: args[0]).deletingLastPathComponent()
let projectDir = scriptDir.deletingLastPathComponent()

let sourcePath = args.count > 1
    ? args[1]
    : projectDir.appendingPathComponent("Resources/AppIcon-source.png").path
let outputDir = args.count > 2
    ? args[2]
    : projectDir.appendingPathComponent("Resources").path

// ============================================================================
// SwiftUI mask view — continuous curvature squircle
// ============================================================================
struct SquircleMask: View {
    let pixelSize: CGFloat
    let inset: CGFloat
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.white)
            .frame(width: pixelSize - 2 * inset, height: pixelSize - 2 * inset)
            .frame(width: pixelSize, height: pixelSize)
    }
}

// ============================================================================
// Main logic — @MainActor for ImageRenderer
// ============================================================================
@MainActor
func renderSquircleMask(pixelSize: Int) -> CGImage {
    let size = CGFloat(pixelSize)
    let scale = size / canvasSize
    let inset = squircleInset * scale
    let radius = cornerRadius * scale

    let maskView = SquircleMask(pixelSize: size, inset: inset, radius: radius)
    let renderer = ImageRenderer(content: maskView)
    renderer.scale = 1.0
    guard let maskCG = renderer.cgImage else {
        fputs("Error: Cannot render squircle mask at \(pixelSize)px\n", stderr)
        exit(1)
    }
    return maskCG
}

@MainActor
func generateIconImage(sourceImage: NSImage, pixelSize: Int) -> CGImage {
    let size = CGFloat(pixelSize)

    let maskCG = renderSquircleMask(pixelSize: pixelSize)

    // Create bitmap context with alpha
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: pixelSize, height: pixelSize,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("Error: Cannot create CGContext\n", stderr)
        exit(1)
    }

    let fullRect = CGRect(x: 0, y: 0, width: size, height: size)

    // Step 1: Draw source artwork scaled to fill
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    sourceImage.draw(in: fullRect, from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    // Step 2: Apply squircle mask via destinationIn blending
    ctx.setBlendMode(.destinationIn)
    ctx.draw(maskCG, in: fullRect)

    guard let result = ctx.makeImage() else {
        fputs("Error: Cannot create final image\n", stderr)
        exit(1)
    }
    return result
}

@MainActor
func savePNG(_ cgImage: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil
    ) else {
        fputs("Error: Cannot create image destination for \(path)\n", stderr)
        exit(1)
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else {
        fputs("Error: Cannot write PNG to \(path)\n", stderr)
        exit(1)
    }
}

@MainActor
func main() {
    guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
        fputs("Error: Cannot load source image at \(sourcePath)\n", stderr)
        exit(1)
    }

    // macOS .iconset requires these exact filenames and pixel sizes
    let iconSizes: [(name: String, pixels: Int)] = [
        ("icon_16x16.png",      16),
        ("icon_16x16@2x.png",   32),
        ("icon_32x32.png",      32),
        ("icon_32x32@2x.png",   64),
        ("icon_128x128.png",    128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png",    256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png",    512),
        ("icon_512x512@2x.png", 1024),
    ]

    let iconsetDir = "\(outputDir)/AppIcon.iconset"
    let fm = FileManager.default
    try? fm.removeItem(atPath: iconsetDir)
    try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

    print("Generating squircle icons from: \(sourcePath)")

    for entry in iconSizes {
        let image = generateIconImage(sourceImage: sourceImage, pixelSize: entry.pixels)
        let path = "\(iconsetDir)/\(entry.name)"
        savePNG(image, to: path)
        print("  \(entry.name) (\(entry.pixels)x\(entry.pixels))")
    }

    // 128x128 preview for README
    let preview = generateIconImage(sourceImage: sourceImage, pixelSize: 128)
    savePNG(preview, to: "\(outputDir)/AppIcon.png")
    print("  AppIcon.png (128x128 preview)")

    // Convert to .icns using iconutil
    print("Converting to .icns via iconutil...")
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["--convert", "icns", "--output", "\(outputDir)/AppIcon.icns", iconsetDir]
    try! proc.run()
    proc.waitUntilExit()

    guard proc.terminationStatus == 0 else {
        fputs("Error: iconutil failed (exit \(proc.terminationStatus))\n", stderr)
        exit(1)
    }

    // Clean up temporary iconset
    try? fm.removeItem(atPath: iconsetDir)

    print("Done!")
    print("  \(outputDir)/AppIcon.icns")
    print("  \(outputDir)/AppIcon.png")
    exit(0)
}

// Schedule on main actor and run
DispatchQueue.main.async {
    main()
}
RunLoop.main.run()
