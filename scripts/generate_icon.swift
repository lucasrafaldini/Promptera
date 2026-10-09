#!/usr/bin/env swift
// Renders the Promptera app icon (vector, every size drawn natively) and packs it
// into an .icns with iconutil.
//
// Usage: swift scripts/generate_icon.swift [output-dir]   (default: Resources)

import AppKit
import CoreGraphics

let outputDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources")
let iconsetDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// macOS-style squircle (superellipse, n = 5) inside `rect`.
func squircle(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let n: CGFloat = 5
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = c.x + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2 / n)
        let y = c.y + b * (st < 0 ? -1 : 1) * pow(abs(st), 2 / n)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// Four-point sparkle — same geometry as `SparkleShape` in DesignSystem.swift.
func sparkle(center c: CGPoint, radius r: CGFloat, pinch: CGFloat = 0.82) -> CGPath {
    let k = r * (1 - pinch) * 0.7
    let path = CGMutablePath()
    path.move(to: CGPoint(x: c.x, y: c.y + r))
    path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y + k))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x + k, y: c.y - k))
    path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y - k))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x - k, y: c.y + k))
    path.closeSubpath()
    return path
}

func roundedRect(_ rect: CGRect, radius: CGFloat, rotation: CGFloat = 0) -> CGPath {
    var t = CGAffineTransform(translationX: rect.midX, y: rect.midY)
        .rotated(by: rotation * .pi / 180)
        .translatedBy(x: -rect.midX, y: -rect.midY)
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: &t)
}

/// Draws the icon on a 1024×1024 design grid (y axis up), scaled to the context.
func drawIcon(_ ctx: CGContext, pixels: Int) {
    let s = CGFloat(pixels) / 1024
    ctx.scaleBy(x: s, y: s)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // Apple's grid: 824pt body centered in 1024 with room for the drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = squircle(in: body)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(rgb(0x4F46E5))
    ctx.fillPath()
    ctx.restoreGState()

    // Body gradient (Aurora: indigo → violet → fuchsia)
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [rgb(0x4338CA), rgb(0x7C3AED), rgb(0xC026D3)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 140, y: 924), end: CGPoint(x: 884, y: 100), options: [])
    // Soft top-left glow
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.32), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 260, y: 860), startRadius: 0, endCenter: CGPoint(x: 260, y: 860), endRadius: 620, options: [])
    // Depth at the bottom-right
    let shade = CGGradient(colorsSpace: space, colors: [rgb(0x1E1B4B, 0), rgb(0x1E1B4B, 0.35)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(shade, startCenter: CGPoint(x: 512, y: 512), startRadius: 300, endCenter: CGPoint(x: 512, y: 512), endRadius: 700, options: [])

    // Stack of prompt cards
    let card = CGRect(x: 262, y: 230, width: 440, height: 520)
    ctx.addPath(roundedRect(card.offsetBy(dx: -34, dy: 26), radius: 64, rotation: 9))
    ctx.setFillColor(rgb(0xFFFFFF, 0.16))
    ctx.fillPath()
    ctx.addPath(roundedRect(card.offsetBy(dx: -14, dy: 12), radius: 64, rotation: 4))
    ctx.setFillColor(rgb(0xFFFFFF, 0.28))
    ctx.fillPath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x1E1B4B, 0.35))
    ctx.addPath(roundedRect(card, radius: 64))
    ctx.setFillColor(rgb(0xFFFFFF, 0.97))
    ctx.fillPath()
    ctx.restoreGState()

    // Prompt "text" lines on the front card
    let lineColor = rgb(0x6D28D9, 0.22)
    let lines: [(CGFloat, CGFloat)] = [(318, 300), (318, 250), (318, 180)]
    for (i, (x, width)) in lines.enumerated() {
        let y = 420 - CGFloat(i) * 70
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: 36), cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.setFillColor(lineColor)
        ctx.fillPath()
    }
    // Prompt chevron
    ctx.setStrokeColor(rgb(0x6D28D9, 0.55))
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 322, y: 640))
    ctx.addLine(to: CGPoint(x: 382, y: 590))
    ctx.addLine(to: CGPoint(x: 322, y: 540))
    ctx.strokePath()

    // Big sparkle: brand-gradient fill with a white rim, overlapping the card corner
    let bigSparkle = sparkle(center: CGPoint(x: 668, y: 632), radius: 206)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 26, color: rgb(0x1E1B4B, 0.45))
    ctx.addPath(bigSparkle)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bigSparkle)
    ctx.setLineWidth(36)
    ctx.setLineJoin(.round)
    ctx.replacePathWithStrokedPath()
    ctx.addPath(bigSparkle)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(sparkle(center: CGPoint(x: 668, y: 632), radius: 178))
    ctx.clip()
    let spark = CGGradient(colorsSpace: space, colors: [rgb(0xFBBF24), rgb(0xF472B6), rgb(0xA855F7)] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(spark, start: CGPoint(x: 560, y: 830), end: CGPoint(x: 800, y: 450), options: [])
    ctx.restoreGState()

    // Small companion sparkles
    ctx.addPath(sparkle(center: CGPoint(x: 828, y: 836), radius: 58))
    ctx.setFillColor(rgb(0xFFFFFF, 0.95))
    ctx.fillPath()
    ctx.addPath(sparkle(center: CGPoint(x: 838, y: 470), radius: 30))
    ctx.setFillColor(rgb(0xFFFFFF, 0.7))
    ctx.fillPath()

    // Subtle inner rim for definition on light backgrounds
    ctx.addPath(bodyPath)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.18))
    ctx.setLineWidth(3)
    ctx.strokePath()
}

func renderPNG(pixels: Int, to url: URL) throws {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    drawIcon(ctx, pixels: pixels)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in sizes {
    try renderPNG(pixels: pixels, to: iconsetDir.appendingPathComponent("\(name).png"))
}
try renderPNG(pixels: 1024, to: outputDir.appendingPathComponent("AppIcon.png"))

let icns = outputDir.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", icns.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconsetDir)
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}
print("✅ \(icns.path)")
