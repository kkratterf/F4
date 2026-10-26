// Draws the F4 app icon with CoreGraphics and writes a full .iconset.
// Usage: swift scripts/make-icon.swift <out.iconset>
// Then:  iconutil -c icns <out.iconset> -o AppIcon.icns
//
// The icon is the app's logo: an F4 keycap, the default shortcut. The letters
// are stroked lines rather than a font, so the icon looks the same on every
// Mac and matches site/logo.svg, which uses the same geometry. Everything is
// drawn in a 1024x1024 design space with the origin at the top left (y grows
// downwards, like SVG), scaled for each size, so the output needs no assets.

import CoreGraphics
import Foundation
import ImageIO

// MARK: - Helpers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    return CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: locations)!
}

/// Superellipse ("squircle") close to the Big Sur icon shape.
func squircle(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, exponent: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * CGFloat.pi
        let c = cos(t)
        let s = sin(t)
        let x = center.x + radiusX * (c < 0 ? -1 : 1) * pow(abs(c), 2 / exponent)
        let y = center.y + radiusY * (s < 0 ? -1 : 1) * pow(abs(s), 2 / exponent)
        if i == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    return path
}

// MARK: - Icon

/// The strokes of "F4", centred on the key's top face.
let glyphs: [[CGPoint]] = {
    let dx: CGFloat = -22
    let lines: [[(CGFloat, CGFloat)]] = [
        [(474, 330), (330, 330), (330, 598)], // F: top bar and stem
        [(330, 456), (448, 456)], // F: middle bar
        [(676, 598), (676, 330), (548, 520), (738, 520)], // 4: stem, diagonal, bar
    ]
    return lines.map { line in line.map { CGPoint(x: $0.0 + dx, y: $0.1) } }
}()

func drawIcon(in ctx: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / 1024
    // y-down design space, like SVG.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)

    // The keycap's skirt: a squircle inside the macOS icon grid (824 pt of
    // 1024), darker towards the bottom, with a soft drop shadow.
    let skirt = squircle(center: CGPoint(x: 512, y: 500), radiusX: 412, radiusY: 412, exponent: 5)
    ctx.saveGState()
    // Shadow offsets live in device space (y up), whatever the CTM.
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 28 * scale, color: rgb(0x000000, 0.28))
    ctx.addPath(skirt)
    ctx.setFillColor(rgb(0xE89A10))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(skirt)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFFB524), rgb(0xC77800)], [0, 1]),
        start: CGPoint(x: 512, y: 88), end: CGPoint(x: 512, y: 912), options: []
    )
    ctx.restoreGState()

    // The top face, set back from the front edge like a key seen from above.
    let face = squircle(center: CGPoint(x: 512, y: 458), radiusX: 348, radiusY: 336, exponent: 5)
    ctx.saveGState()
    ctx.addPath(face)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFFE27E), rgb(0xFFC43D)], [0, 1]),
        start: CGPoint(x: 512, y: 122), end: CGPoint(x: 512, y: 794), options: []
    )
    ctx.restoreGState()
    ctx.addPath(face)
    ctx.setStrokeColor(rgb(0xFFF3C4, 0.7))
    ctx.setLineWidth(6)
    ctx.strokePath()

    // "F4", in round strokes.
    for line in glyphs {
        ctx.addLines(between: line)
    }
    ctx.setStrokeColor(rgb(0x241809))
    ctx.setLineWidth(64)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

// MARK: - Output

func renderPNG(pixels: Int, to url: URL) -> Bool {
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    drawIcon(in: ctx, pixels: pixels)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: swift make-icon.swift <out.iconset>\n".data(using: .utf8)!)
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.removeItem(at: outDir)
do {
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write("make-icon: cannot create \(outDir.path): \(error)\n".data(using: .utf8)!)
    exit(1)
}

// (point size, scale) pairs required by iconutil.
let variants: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]
var failed = false
for (points, factor) in variants {
    let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    let url = outDir.appendingPathComponent(name)
    if renderPNG(pixels: points * factor, to: url) {
        print("make-icon: wrote \(name) (\(points * factor)px)")
    } else {
        FileHandle.standardError.write("make-icon: failed to write \(name)\n".data(using: .utf8)!)
        failed = true
    }
}
exit(failed ? 1 : 0)
