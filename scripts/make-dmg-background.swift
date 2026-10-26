// Draws the background of the F4 installer window (dist/F4-x.y.z.dmg) and
// writes background.png (@1x) and background@2x.png into a folder.
// Usage: swift scripts/make-dmg-background.swift <out dir>
//
// A tall window in two halves. On top, a dark keyboard: the function row,
// with the F4 app icon (a yellow F4 keycap) sitting in the F4 slot and
// glowing. Below, a lighter half where Finder writes the icon labels (it
// draws them black or white with the system appearance, so they must sit on
// a mid grey), with chevrons pointing down to the Applications folder.
//
// Drawn in code, like the app icon: no image is committed. The geometry must
// match the window and icon positions in scripts/build-dmg.sh.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

let width = 380
let height = 560
// Icon centres in build-dmg.sh, in Finder coordinates (origin top left).
let appCentre = CGPoint(x: 190, y: 214)
let applicationsCentre = CGPoint(x: 190, y: 424)
// Where the dark keyboard ends and the label half begins: just under the
// app icon (112 pt in build-dmg.sh), above its label.
let split: CGFloat = 274

// Keys next to F4: same size as the keycap in the icon (824/1024 of 112 pt).
let keySize: CGFloat = 92
let keyGap: CGFloat = 14
let keyRadius: CGFloat = 16

let yellow: UInt32 = 0xFFC43D
let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    return CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: locations)!
}

func roundedRect(centre: CGPoint, size: CGFloat, radius: CGFloat) -> CGPath {
    let rect = CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Draws one line of text centred on `x` with its baseline at `y`.
func drawText(_ text: String, fontName: String, size: CGFloat, color: CGColor,
              x: CGFloat, y: CGFloat, alignRight: Bool = false, in ctx: CGContext) {
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color,
    ]
    let string = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    let line = CTLineCreateWithAttributedString(string)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    ctx.saveGState()
    // Text draws y-up, so flip back for this one line.
    ctx.translateBy(x: alignRight ? x - bounds.width : x - bounds.width / 2, y: y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// An arc as points, so it looks the same whatever the CTM orientation.
/// Angles in degrees, 0 = +x, 90 = down (the design space is y-down).
func arc(center: CGPoint, radius: CGFloat, from start: CGFloat, to end: CGFloat) -> [CGPoint] {
    let steps = 48
    return (0...steps).map { i in
        let a = (start + (end - start) * CGFloat(i) / CGFloat(steps)) * .pi / 180
        return CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
    }
}

// MARK: - Key glyphs (the Mac's function-row symbols, as thin strokes)

func strokeGlyph(_ path: CGPath, in ctx: CGContext) {
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.42))
    ctx.setLineWidth(2.4)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

/// F2: brightness up.
func sun(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.addEllipse(in: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        path.move(to: CGPoint(x: c.x + cos(a) * 10, y: c.y + sin(a) * 10))
        path.addLine(to: CGPoint(x: c.x + cos(a) * 14, y: c.y + sin(a) * 14))
    }
    return path
}

/// F3: Mission Control.
func missionControl(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    for rect in [
        CGRect(x: c.x - 14, y: c.y - 10, width: 12, height: 9),
        CGRect(x: c.x + 2, y: c.y - 10, width: 12, height: 9),
        CGRect(x: c.x - 14, y: c.y + 3, width: 28, height: 9),
    ] {
        path.addRoundedRect(in: rect, cornerWidth: 2, cornerHeight: 2)
    }
    return path
}

/// F5: dictation.
func microphone(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.addRoundedRect(in: CGRect(x: c.x - 5, y: c.y - 13, width: 10, height: 17), cornerWidth: 5, cornerHeight: 5)
    // The cradle: the lower half of a circle.
    path.addLines(between: arc(center: CGPoint(x: c.x, y: c.y - 2), radius: 10, from: 180, to: 0))
    path.move(to: CGPoint(x: c.x, y: c.y + 8))
    path.addLine(to: CGPoint(x: c.x, y: c.y + 13))
    return path
}

/// F6: Do Not Disturb (cut off by the window edge, so a plain crescent).
func moon(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    let outer = arc(center: c, radius: 12, from: -60, to: -300)
    let inner = arc(center: CGPoint(x: c.x + 6, y: c.y - 3), radius: 9, from: 70, to: 265)
    path.addLines(between: outer + inner)
    path.closeSubpath()
    return path
}

func drawKey(centre: CGPoint, label: String, glyph: CGPath, in ctx: CGContext, scale: CGFloat) {
    let body = roundedRect(centre: centre, size: keySize, radius: keyRadius)
    ctx.saveGState()
    // Shadow offsets live in device space (y up), whatever the CTM.
    ctx.setShadow(offset: CGSize(width: 0, height: -3 * scale), blur: 6 * scale, color: rgb(0x000000, 0.6))
    ctx.addPath(body)
    ctx.setFillColor(rgb(0x1D1D20))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0x232326), rgb(0x18181A)], [0, 1]),
        start: CGPoint(x: centre.x, y: centre.y - keySize / 2),
        end: CGPoint(x: centre.x, y: centre.y + keySize / 2), options: []
    )
    ctx.restoreGState()

    ctx.addPath(roundedRect(centre: centre, size: keySize - 1, radius: keyRadius))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.07))
    ctx.setLineWidth(1)
    ctx.strokePath()

    strokeGlyph(glyph, in: ctx)
    drawText(label, fontName: "Helvetica", size: 12, color: rgb(0xFFFFFF, 0.38),
             x: centre.x + keySize / 2 - 12, y: centre.y + keySize / 2 - 12, alignRight: true, in: ctx)
}

// MARK: - Background

func draw(in ctx: CGContext, scale: CGFloat) {
    // Finder coordinates: origin top left, y downwards.
    ctx.translateBy(x: 0, y: CGFloat(height) * scale)
    ctx.scaleBy(x: scale, y: -scale)
    let w = CGFloat(width)
    let h = CGFloat(height)
    let top = CGRect(x: 0, y: 0, width: w, height: split)
    let bottom = CGRect(x: 0, y: split, width: w, height: h - split)

    // The keyboard: near black.
    ctx.saveGState()
    ctx.clip(to: top)
    ctx.drawLinearGradient(
        gradient([rgb(0x0C0C0E), rgb(0x19181A)], [0, 1]),
        start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: split), options: []
    )
    ctx.restoreGState()

    // The label half: a mid grey, readable with black and white labels,
    // warmed a little by the key's glow.
    ctx.saveGState()
    ctx.clip(to: bottom)
    ctx.drawLinearGradient(
        gradient([rgb(0x55565B), rgb(0x7C7E84)], [0, 1]),
        start: CGPoint(x: 0, y: split), end: CGPoint(x: 0, y: h), options: []
    )
    ctx.drawRadialGradient(
        gradient([rgb(yellow, 0.10), rgb(yellow, 0)], [0, 1]),
        startCenter: CGPoint(x: appCentre.x, y: split), startRadius: 0,
        endCenter: CGPoint(x: appCentre.x, y: split), endRadius: 220, options: []
    )
    ctx.restoreGState()

    // The function row around the icon; F2 and F6 run off the edges.
    let step = keySize + keyGap
    let keys: [(CGFloat, String, (CGPoint) -> CGPath)] = [
        (-2, "F2", sun), (-1, "F3", missionControl), (1, "F5", microphone), (2, "F6", moon),
    ]
    for (offset, label, glyph) in keys {
        let centre = CGPoint(x: appCentre.x + offset * step, y: appCentre.y)
        drawKey(centre: centre, label: label, glyph: glyph(CGPoint(x: centre.x, y: centre.y - 8)), in: ctx, scale: scale)
    }

    // The F4 slot the icon sits in: a dark well with a yellow rim.
    let well = keySize + 12
    ctx.addPath(roundedRect(centre: appCentre, size: well, radius: keyRadius + 6))
    ctx.setFillColor(rgb(0x070708))
    ctx.fillPath()
    ctx.addPath(roundedRect(centre: appCentre, size: well - 1.5, radius: keyRadius + 6))
    ctx.setStrokeColor(rgb(yellow, 0.55))
    ctx.setLineWidth(1.5)
    ctx.strokePath()

    // The glow, over the keys so it lights their edges too.
    ctx.saveGState()
    ctx.clip(to: top)
    ctx.drawRadialGradient(
        gradient([rgb(0xFFB524, 0.34), rgb(0xFF9A1A, 0.12), rgb(0xFF9A1A, 0)], [0, 0.45, 1]),
        startCenter: appCentre, startRadius: 0, endCenter: appCentre, endRadius: 190, options: []
    )
    ctx.restoreGState()

    // A hairline where the keyboard ends.
    ctx.setFillColor(rgb(0xFFFFFF, 0.10))
    ctx.fill(CGRect(x: 0, y: split, width: w, height: 1))

    drawText("Drag F4 to Applications", fontName: "Helvetica-Bold", size: 20,
             color: rgb(0xFFFFFF, 0.92), x: w / 2, y: 72, in: ctx)
    drawText("Then press F4 anywhere", fontName: "Helvetica", size: 13,
             color: rgb(0xFFFFFF, 0.5), x: w / 2, y: 96, in: ctx)

    // Three chevrons down to Applications, the last one lit like the key.
    let chevronTop = (split + 20 + applicationsCentre.y - 56) / 2 - 8
    let chevrons: [(CGColor, Bool)] = [
        (rgb(0xFFFFFF, 0.22), false), (rgb(0xFFFFFF, 0.45), false), (rgb(yellow), true),
    ]
    for (index, (color, lit)) in chevrons.enumerated() {
        let y = chevronTop + CGFloat(index) * 12
        ctx.saveGState()
        if lit {
            ctx.setShadow(offset: .zero, blur: 8 * scale, color: rgb(yellow, 0.9))
        }
        ctx.move(to: CGPoint(x: w / 2 - 13, y: y))
        ctx.addLine(to: CGPoint(x: w / 2, y: y + 11))
        ctx.addLine(to: CGPoint(x: w / 2 + 13, y: y))
        ctx.setStrokeColor(color)
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }
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
