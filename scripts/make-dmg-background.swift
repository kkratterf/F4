// Draws the background of the F4 installer window (dist/F4-x.y.z.dmg) and
// writes background.png (@1x) and background@2x.png into a folder.
// Usage: swift scripts/make-dmg-background.swift <out dir>
//
// A tall window in two halves. On top, a dark keyboard seen from above: the
// function row in focus, with the F4 app icon (a yellow F4 keycap) sitting
// in the F4 slot and lighting up the keys around it, and the row behind it
// fading into the dark. Below, a mid grey half where Finder writes the icon
// labels (it draws them black or white with the system appearance, so they
// must sit on a mid grey), with chevrons pointing down to Applications.
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
// Where the keyboard ends and the label half begins: just under the app
// icon (112 pt in build-dmg.sh), above its label.
let split: CGFloat = 270

// Keys: the size of the keycap in the icon (824/1024 of 112 pt).
let keySize: CGFloat = 90
let keyStep: CGFloat = 104
let keyRadius: CGFloat = 17

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

/// Fills `path` with a vertical gradient from `top` to `bottom`.
func fill(_ path: CGPath, top: CGColor, bottom: CGColor, in ctx: CGContext) {
    let box = path.boundingBox
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([top, bottom], [0, 1]),
        start: CGPoint(x: box.midX, y: box.minY), end: CGPoint(x: box.midX, y: box.maxY), options: []
    )
    ctx.restoreGState()
}

/// Draws one line of text centred on `x` with its baseline at `y`.
func drawText(_ text: String, fontName: String, size: CGFloat, color: CGColor,
              x: CGFloat, y: CGFloat, in ctx: CGContext) {
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
    ctx.translateBy(x: x - bounds.width / 2, y: y)
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

/// F2: brightness up.
func sun(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.addEllipse(in: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10))
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        path.move(to: CGPoint(x: c.x + cos(a) * 8.5, y: c.y + sin(a) * 8.5))
        path.addLine(to: CGPoint(x: c.x + cos(a) * 11.5, y: c.y + sin(a) * 11.5))
    }
    return path
}

/// F3: Mission Control.
func missionControl(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    for rect in [
        CGRect(x: c.x - 12, y: c.y - 8, width: 10, height: 7),
        CGRect(x: c.x + 2, y: c.y - 8, width: 10, height: 7),
        CGRect(x: c.x - 12, y: c.y + 2, width: 24, height: 7),
    ] {
        path.addRoundedRect(in: rect, cornerWidth: 1.5, cornerHeight: 1.5)
    }
    return path
}

/// F5: dictation.
func microphone(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.addRoundedRect(in: CGRect(x: c.x - 4, y: c.y - 11, width: 8, height: 14), cornerWidth: 4, cornerHeight: 4)
    // The cradle: the lower half of a circle.
    path.addLines(between: arc(center: CGPoint(x: c.x, y: c.y - 2), radius: 8, from: 180, to: 0))
    path.move(to: CGPoint(x: c.x, y: c.y + 6))
    path.addLine(to: CGPoint(x: c.x, y: c.y + 10))
    return path
}

/// F6: Do Not Disturb.
func moon(_ c: CGPoint) -> CGPath {
    let path = CGMutablePath()
    let outer = arc(center: c, radius: 10, from: -60, to: -300)
    let inner = arc(center: CGPoint(x: c.x + 5, y: c.y - 2.5), radius: 7.5, from: 70, to: 265)
    path.addLines(between: outer + inner)
    path.closeSubpath()
    return path
}

// MARK: - Keys

/// One dark keycap. Keys in the function row carry a symbol and a label;
/// the out-of-focus row behind it carries nothing. The side facing F4
/// catches its light.
func drawKey(centre: CGPoint, label: String?, glyph: CGPath?, in ctx: CGContext, scale: CGFloat) {
    let body = roundedRect(centre: centre, size: keySize, radius: keyRadius)
    ctx.saveGState()
    // Shadow offsets live in device space (y up), whatever the CTM.
    ctx.setShadow(offset: CGSize(width: 0, height: -4 * scale), blur: 8 * scale, color: rgb(0x000000, 0.7))
    ctx.addPath(body)
    ctx.setFillColor(rgb(0x141416))
    ctx.fillPath()
    ctx.restoreGState()
    fill(body, top: rgb(0x1C1C1F), bottom: rgb(0x0F0F11), in: ctx)

    // The top face, set back from the skirt and lit from above.
    let faceCentre = CGPoint(x: centre.x, y: centre.y - 2)
    fill(roundedRect(centre: faceCentre, size: keySize - 8, radius: keyRadius - 3),
         top: rgb(0x2A2A2E), bottom: rgb(0x1D1D20), in: ctx)
    ctx.addPath(roundedRect(centre: faceCentre, size: keySize - 8.5, radius: keyRadius - 3))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.06))
    ctx.setLineWidth(1)
    ctx.strokePath()

    // Rim light: the edge towards F4 glows, fading across the key and with
    // the distance from F4.
    let towards = appCentre.x - centre.x
    let strength = (label == nil ? 0.2 : 0.35) * max(0, 1 - abs(towards) / 320)
    if strength > 0 {
        let side: CGFloat = towards < 0 ? -1 : 1
        ctx.saveGState()
        ctx.addPath(roundedRect(centre: centre, size: keySize - 1, radius: keyRadius))
        ctx.setLineWidth(1.2)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([rgb(yellow, 0), rgb(yellow, strength)], [0, 1]),
            start: CGPoint(x: centre.x - side * keySize / 2, y: centre.y),
            end: CGPoint(x: centre.x + side * keySize / 2, y: centre.y), options: []
        )
        ctx.restoreGState()
    }

    if let glyph = glyph {
        ctx.addPath(glyph)
        ctx.setStrokeColor(rgb(0xFFFFFF, 0.5))
        ctx.setLineWidth(2)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }
    if let label = label {
        drawText(label, fontName: "Helvetica", size: 11, color: rgb(0xFFFFFF, 0.45),
                 x: centre.x, y: centre.y + 22, in: ctx)
    }
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

    // The keyboard.
    ctx.saveGState()
    ctx.clip(to: top)
    ctx.drawLinearGradient(
        gradient([rgb(0x070708), rgb(0x141315)], [0, 1]),
        start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: split), options: []
    )

    // The row behind, staggered by half a key, fading into the dark.
    let backRow = appCentre.y - keyStep
    for i in -3...2 {
        let centre = CGPoint(x: appCentre.x + keyStep / 2 + CGFloat(i) * keyStep, y: backRow)
        drawKey(centre: centre, label: nil, glyph: nil, in: ctx, scale: scale)
    }
    let fadeEnd = appCentre.y - keyStep / 2 + 4
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: fadeEnd))
    ctx.drawLinearGradient(
        gradient([rgb(0x070708, 1), rgb(0x070708, 0.35)], [0, 1]),
        start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: fadeEnd), options: []
    )
    ctx.restoreGState()

    // The function row: F2 and F6 run off the edges.
    let keys: [(CGFloat, String, (CGPoint) -> CGPath)] = [
        (-2, "F2", sun), (-1, "F3", missionControl), (1, "F5", microphone), (2, "F6", moon),
    ]
    for (offset, label, glyph) in keys {
        let centre = CGPoint(x: appCentre.x + offset * keyStep, y: appCentre.y)
        drawKey(centre: centre, label: label, glyph: glyph(CGPoint(x: centre.x, y: centre.y - 9)), in: ctx, scale: scale)
    }

    // The F4 slot the icon sits in: a dark well with a yellow rim.
    let well = keySize + 14
    ctx.addPath(roundedRect(centre: appCentre, size: well, radius: keyRadius + 7))
    ctx.setFillColor(rgb(0x050506))
    ctx.fillPath()
    ctx.addPath(roundedRect(centre: appCentre, size: well - 1.4, radius: keyRadius + 7))
    ctx.setStrokeColor(rgb(yellow, 0.6))
    ctx.setLineWidth(1.4)
    ctx.strokePath()

    // The glow, over the keys so it lights them too.
    ctx.drawRadialGradient(
        gradient([rgb(0xFFB524, 0.42), rgb(0xFF9A1A, 0.16), rgb(0xFF8A00, 0)], [0, 0.35, 1]),
        startCenter: appCentre, startRadius: 0, endCenter: appCentre, endRadius: 210, options: []
    )
    ctx.restoreGState()

    // The label half: a mid grey, readable with black and white labels.
    ctx.saveGState()
    ctx.clip(to: bottom)
    ctx.drawLinearGradient(
        gradient([rgb(0x4C4D52), rgb(0x76787E)], [0, 1]),
        start: CGPoint(x: 0, y: split), end: CGPoint(x: 0, y: h), options: []
    )
    // The key's light reflected on it: a wide, flat ellipse at the seam.
    ctx.saveGState()
    ctx.translateBy(x: appCentre.x, y: split)
    ctx.scaleBy(x: 1, y: 110.0 / 210.0)
    ctx.drawRadialGradient(
        gradient([rgb(yellow, 0.20), rgb(yellow, 0)], [0, 1]),
        startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 210, options: []
    )
    ctx.restoreGState()
    // A soft pool of light where Applications sits.
    ctx.drawRadialGradient(
        gradient([rgb(0xFFFFFF, 0.07), rgb(0xFFFFFF, 0)], [0, 1]),
        startCenter: applicationsCentre, startRadius: 0, endCenter: applicationsCentre, endRadius: 170, options: []
    )
    ctx.restoreGState()

    // The seam: a hairline, yellow in the middle under the key.
    ctx.setFillColor(rgb(0xFFFFFF, 0.12))
    ctx.fill(CGRect(x: 0, y: split, width: w, height: 1))
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: split, width: w, height: 1.2))
    ctx.drawLinearGradient(
        gradient([rgb(yellow, 0), rgb(yellow, 0.65), rgb(yellow, 0)], [0, 0.5, 1]),
        start: CGPoint(x: 0, y: split), end: CGPoint(x: w, y: split), options: []
    )
    ctx.restoreGState()

    // Three chevrons down to Applications, the last one lit like the key.
    let chevrons: [(CGColor, Bool)] = [
        (rgb(0xFFFFFF, 0.18), false), (rgb(0xFFFFFF, 0.38), false), (rgb(yellow), true),
    ]
    for (index, (color, lit)) in chevrons.enumerated() {
        let y = 320 + CGFloat(index) * 11
        ctx.saveGState()
        if lit {
            ctx.setShadow(offset: .zero, blur: 7 * scale, color: rgb(yellow, 1))
        }
        ctx.move(to: CGPoint(x: w / 2 - 12, y: y))
        ctx.addLine(to: CGPoint(x: w / 2, y: y + 10))
        ctx.addLine(to: CGPoint(x: w / 2 + 12, y: y))
        ctx.setStrokeColor(color)
        ctx.setLineWidth(3.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

/// Film grain, so the large gradients do not band: a small, fixed random
/// offset on every pixel (the image is opaque, so premultiplying is moot).
func addGrain(to ctx: CGContext) {
    guard let data = ctx.data else { return }
    let pixels = data.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * ctx.height)
    var seed: UInt32 = 0xF4F4_F4F4
    for y in 0..<ctx.height {
        for x in 0..<ctx.width {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let delta = Int((seed >> 24) % 11) - 5
            let offset = y * ctx.bytesPerRow + x * 4
            for channel in 0..<3 {
                let value = Int(pixels[offset + channel]) + delta
                pixels[offset + channel] = UInt8(max(0, min(255, value)))
            }
        }
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
    addGrain(to: ctx)
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
