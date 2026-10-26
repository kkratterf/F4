// Draws the background of the F4 installer window (dist/F4-x.y.z.dmg) and
// writes background.png (@1x) and background@2x.png into a folder.
// Usage: swift scripts/make-dmg-background.swift <out dir>
//
// Drawn in code, like the app icon: no image is committed. The geometry must
// match the window and icon positions in scripts/build-dmg.sh.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

let width = 660
let height = 400
// Icon centres in build-dmg.sh, in Finder coordinates (origin top left).
let appCentre = CGPoint(x: 165, y: 200)
let applicationsCentre = CGPoint(x: 495, y: 200)

let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func draw(in ctx: CGContext, scale: CGFloat) {
    // Finder coordinates: origin top left, y downwards.
    ctx.translateBy(x: 0, y: CGFloat(height) * scale)
    ctx.scaleBy(x: scale, y: -scale)

    guard let background = CGGradient(
        colorsSpace: sRGB,
        colors: [rgb(0xFFF3D1), rgb(0xFFD87A)] as CFArray,
        locations: [0, 1]
    ) else { return }
    ctx.drawLinearGradient(
        background,
        start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(height)), options: []
    )

    // "Drag me here" arrow between the two icons.
    let y = appCentre.y
    let from = appCentre.x + 96
    let to = applicationsCentre.x - 96
    ctx.setStrokeColor(rgb(0x2A1B12, 0.45))
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [14, 12])
    ctx.move(to: CGPoint(x: from, y: y))
    ctx.addLine(to: CGPoint(x: to - 12, y: y))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    // Arrow head.
    ctx.setFillColor(rgb(0x2A1B12, 0.45))
    ctx.move(to: CGPoint(x: to + 6, y: y))
    ctx.addLine(to: CGPoint(x: to - 18, y: y - 14))
    ctx.addLine(to: CGPoint(x: to - 18, y: y + 14))
    ctx.closePath()
    ctx.fillPath()

    // Title and hint. Core Text would need a font lookup; a drawn wordmark
    // would clash with the icons, so the text is kept to the system font.
    let title = "Drag F4 into Applications" as CFString
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: rgb(0x2A1B12, 0.75),
    ]
    let string = CFAttributedStringCreate(nil, title, attributes as CFDictionary)!
    let linePath = CTLineCreateWithAttributedString(string)
    let bounds = CTLineGetBoundsWithOptions(linePath, [])
    ctx.saveGState()
    // Text draws y-up, so flip back for this one line.
    ctx.translateBy(x: (CGFloat(width) - bounds.width) / 2, y: 92)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(linePath, ctx)
    ctx.restoreGState()
}

func writePNG(scale: CGFloat, to url: URL) -> Bool {
    let pixelsWide = Int(CGFloat(width) * scale)
    let pixelsHigh = Int(CGFloat(height) * scale)
    guard let ctx = CGContext(
        data: nil, width: pixelsWide, height: pixelsHigh,
        bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    draw(in: ctx, scale: scale)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: swift make-dmg-background.swift <out dir>\n".data(using: .utf8)!)
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.removeItem(at: outDir)
do {
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write("make-dmg-background: cannot create \(outDir.path): \(error)\n".data(using: .utf8)!)
    exit(1)
}

var failed = false
for (name, scale) in [("background.png", CGFloat(1)), ("background@2x.png", CGFloat(2))] {
    let url = outDir.appendingPathComponent(name)
    if writePNG(scale: scale, to: url) {
        print("make-dmg-background: wrote \(name)")
    } else {
        FileHandle.standardError.write("make-dmg-background: failed to write \(name)\n".data(using: .utf8)!)
        failed = true
    }
}
exit(failed ? 1 : 0)
