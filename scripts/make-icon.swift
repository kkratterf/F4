// Draws the F4 app icon with CoreGraphics and writes a full .iconset.
// Usage: swift scripts/make-icon.swift <out.iconset>
// Then:  iconutil -c icns <out.iconset> -o AppIcon.icns
//
// The face is the same basito face as Sources/F4/Panel/BasitoFace.swift, drawn
// in code: no frame from the show is ever committed. Everything is drawn in a
// 1024x1024 design space with the origin at the top left (y grows downwards,
// like BasitoFace), scaled for each size, so the output needs no assets.

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

func ellipse(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGPath {
    return CGPath(ellipseIn: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0), transform: nil)
}

/// Superellipse ("squircle") close to the Big Sur icon shape.
func squircle(center: CGPoint, radius: CGFloat, exponent: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * CGFloat.pi
        let c = cos(t)
        let s = sin(t)
        let x = center.x + radius * (c < 0 ? -1 : 1) * pow(abs(c), 2 / exponent)
        let y = center.y + radius * (s < 0 ? -1 : 1) * pow(abs(s), 2 / exponent)
        if i == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    return path
}

/// An arc as a polyline, so it looks the same whatever the CTM orientation.
/// Angles in degrees, 0 = +x, 90 = down (the design space is y-down).
func arc(center: CGPoint, radius: CGFloat, from start: CGFloat, to end: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let steps = 96
    for i in 0...steps {
        let a = (start + (end - start) * CGFloat(i) / CGFloat(steps)) * CGFloat.pi / 180
        let p = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    return path
}

// MARK: - Icon

let ink = rgb(0x3D291F)

func drawIcon(in ctx: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / 1024
    // y-down design space, like SwiftUI's Canvas in BasitoFace.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)

    // Body: a squircle inside the macOS icon grid (824 pt of 1024), with a soft drop shadow.
    let body = squircle(center: CGPoint(x: 512, y: 500), radius: 412, exponent: 5)
    ctx.saveGState()
    // Shadow offsets live in device space (y up), whatever the CTM.
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 28 * scale, color: rgb(0x000000, 0.28))
    ctx.addPath(body)
    ctx.setFillColor(rgb(0xFFC43D))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFFD866), rgb(0xFFB524)], [0, 1]),
        start: CGPoint(x: 512, y: 88), end: CGPoint(x: 512, y: 912), options: []
    )

    // Face, hair, brows, eyes and mouth: BasitoFace's 512 space, doubled and nudged.
    ctx.translateBy(x: 0, y: -12)
    ctx.scaleBy(x: 2, y: 2)
    let line: CGFloat = 9

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * scale), blur: 20 * scale, color: rgb(0x7A4A00, 0.3))
    ctx.addPath(ellipse(116, 104, 396, 430))
    ctx.setFillColor(rgb(0xFAE0C4))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(ellipse(116, 104, 396, 430))
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(line)
    ctx.strokePath()

    // Hair: the top of a squashed circle.
    let hair = CGMutablePath()
    hair.addPath(arc(center: CGPoint(x: 256, y: 0), radius: 150, from: 180, to: 360))
    hair.closeSubpath()
    var squash = CGAffineTransform(translationX: 0, y: 168).scaledBy(x: 1, y: 0.62)
    if let squashed = hair.copy(using: &squash) {
        ctx.addPath(squashed)
        ctx.setFillColor(rgb(0x5C4029))
        ctx.fillPath()
    }

    for x in [CGFloat(200), CGFloat(312)] {
        // Eyebrows raised as high as they go.
        ctx.addPath(arc(center: CGPoint(x: x, y: 214), radius: 42, from: 205, to: 335))
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(13)
        ctx.setLineCap(.round)
        ctx.strokePath()
        // Round eyes, staring.
        let eye = ellipse(x - 37, 226, x + 37, 304)
        ctx.addPath(eye)
        ctx.setFillColor(rgb(0xFFFFFF))
        ctx.fillPath()
        ctx.addPath(eye)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(line)
        ctx.strokePath()
        ctx.addPath(ellipse(x - 12, 255, x + 12, 279))
        ctx.setFillColor(rgb(0x1F1F1F))
        ctx.fillPath()
    }

    // Mouth: a small, speechless "o".
    let mouth = ellipse(232, 346, 280, 396)
    ctx.addPath(mouth)
    ctx.setFillColor(rgb(0x782929))
    ctx.fillPath()
    ctx.addPath(mouth)
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(line)
    ctx.strokePath()
    ctx.restoreGState()

    // A light rim, so the icon reads on dark Docks and Finder backgrounds.
    ctx.addPath(body)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.35))
    ctx.setLineWidth(6)
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
