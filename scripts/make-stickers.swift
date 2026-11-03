// Draws F4's starter stickers with CoreGraphics and CoreText and writes
// them as transparent 512x512 PNGs, the size of a WhatsApp sticker.
// Usage: swift scripts/make-stickers.swift <out-folder>
//
// Nothing is committed: build-app.sh runs this and puts the stickers in
// F4.app/Contents/Resources/Starter/Stickers. Each sticker is a word or two
// in the classic sticker style (thick white border, soft shadow, a slight
// tilt), plus the F4 keycap from the app icon. The file name is what the
// panel shows and searches.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvas = 512
let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

struct Sticker {
    let name: String
    /// Lines of text; "\n" starts a new line.
    let text: String
    let fill: UInt32
    let outline: UInt32
    /// Degrees, counter-clockwise.
    let tilt: CGFloat
}

let stickers: [Sticker] = [
    Sticker(name: "basito", text: "BASITO", fill: 0xFFD43B, outline: 0x1D1D1F, tilt: 6),
    Sticker(name: "dai dai dai", text: "DAI\nDAI\nDAI!", fill: 0xFF6B6B, outline: 0x5A0F12, tilt: -5),
    Sticker(name: "smarmella", text: "SMAR-\nMELLA", fill: 0xFFA94D, outline: 0x5C2B00, tilt: 4),
    Sticker(name: "apri tutto", text: "APRI\nTUTTO!", fill: 0xFFE066, outline: 0x4D3B00, tilt: -6),
    Sticker(name: "lol", text: "LOL", fill: 0x74C0FC, outline: 0x0B3A66, tilt: -8),
    Sticker(name: "nope", text: "NOPE", fill: 0xFF8787, outline: 0x5A0F12, tilt: 7),
    Sticker(name: "same", text: "SAME", fill: 0xB197FC, outline: 0x2B1066, tilt: -4),
    Sticker(name: "plus one", text: "+1", fill: 0x69DB7C, outline: 0x0B4D1A, tilt: 5),
    Sticker(name: "ship it", text: "SHIP\nIT", fill: 0x4DABF7, outline: 0x0B3A66, tilt: -7),
    Sticker(name: "big mood", text: "BIG\nMOOD", fill: 0xF783AC, outline: 0x5C0B2E, tilt: 6),
    Sticker(name: "bruh", text: "BRUH", fill: 0xADB5BD, outline: 0x212529, tilt: -5),
    Sticker(name: "wow", text: "WOW", fill: 0xFFD43B, outline: 0x5C3D00, tilt: 8),
]

// MARK: - Text as a path

let fontNames = ["HelveticaNeue-CondensedBlack", "Impact", "Helvetica-Bold"]

func font(size: CGFloat) -> CTFont {
    for name in fontNames {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        if (CTFontCopyPostScriptName(font) as String) == name { return font }
    }
    return CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)!
}

/// The outlines of one line of text, with its baseline at y = 0.
func path(of text: String, font: CTFont) -> CGPath {
    let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let runAttributes = CTRunGetAttributes(run) as NSDictionary
        let runFont = runAttributes[kCTFontAttributeName as String] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        for index in 0..<count {
            if let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) {
                path.addPath(glyph, transform: CGAffineTransform(translationX: positions[index].x, y: positions[index].y))
            }
        }
    }
    return path
}

/// All lines stacked and centred, scaled to fit `box`, tilted, centred on the canvas.
func textPath(_ text: String, box: CGFloat, tilt: CGFloat) -> CGPath {
    let font = font(size: 200)
    let lines = text.components(separatedBy: "\n").map { path(of: $0, font: font) }
    let lineHeight = CTFontGetCapHeight(font) * 1.25
    let block = CGMutablePath()
    for (index, line) in lines.enumerated() {
        let bounds = line.boundingBoxOfPath
        let y = CGFloat(lines.count - 1 - index) * lineHeight
        block.addPath(line, transform: CGAffineTransform(translationX: -bounds.midX, y: y))
    }
    let bounds = block.boundingBoxOfPath
    let scale = min(box / bounds.width, box / bounds.height)
    var transform = CGAffineTransform(translationX: CGFloat(canvas) / 2, y: CGFloat(canvas) / 2)
        .rotated(by: tilt * .pi / 180)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -bounds.midX, y: -bounds.midY)
    return block.copy(using: &transform)!
}

// MARK: - Drawing

func context() -> CGContext {
    let context = CGContext(
        data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setLineJoin(.round)
    context.setLineCap(.round)
    return context
}

/// The white sticker border with a soft shadow, then the shape itself.
func drawSticker(_ shape: CGPath, in context: CGContext, border: CGFloat = 34, body: (CGContext) -> Void) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x000000, 0.35))
    context.addPath(shape)
    context.setLineWidth(border * 2)
    context.setStrokeColor(rgb(0xFFFFFF))
    context.setFillColor(rgb(0xFFFFFF))
    context.drawPath(using: .fillStroke)
    context.restoreGState()
    body(context)
}

func textSticker(_ sticker: Sticker) -> CGImage {
    let context = context()
    let shape = textPath(sticker.text, box: 360, tilt: sticker.tilt)
    drawSticker(shape, in: context) { context in
        context.addPath(shape)
        context.setLineWidth(10)
        context.setStrokeColor(rgb(sticker.outline))
        context.setFillColor(rgb(sticker.fill))
        context.drawPath(using: .fillStroke)
        // Fill again over the inner half of the outline, so it stays crisp.
        context.addPath(shape)
        context.fillPath()
    }
    return context.makeImage()!
}

/// The F4 keycap, as in the app icon.
func keycapSticker() -> CGImage {
    let context = context()
    let rect = CGRect(x: 96, y: 96, width: 320, height: 320)
    var tilt = CGAffineTransform(translationX: 256, y: 256).rotated(by: -6 * .pi / 180).translatedBy(x: -256, y: -256)
    let body = CGPath(roundedRect: rect, cornerWidth: 64, cornerHeight: 64, transform: &tilt)
    let face = CGPath(roundedRect: rect.insetBy(dx: 30, dy: 30).offsetBy(dx: 0, dy: 26), cornerWidth: 44, cornerHeight: 44, transform: &tilt)
    drawSticker(body, in: context) { context in
        context.addPath(body)
        context.setFillColor(rgb(0xE0A800))
        context.fillPath()
        context.addPath(face)
        context.setFillColor(rgb(0xFFD43B))
        context.fillPath()
        let label = textPath("F4", box: 150, tilt: -6)
        var lift = CGAffineTransform(translationX: 0, y: 26)
        context.addPath(label.copy(using: &lift)!)
        context.setFillColor(rgb(0x1D1D1F))
        context.fillPath()
    }
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(url.path)") }
}

// MARK: - Main

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-stickers.swift <out-folder>\n".utf8))
    exit(2)
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
write(keycapSticker(), to: folder.appendingPathComponent("f4 keycap.png"))
for sticker in stickers {
    write(textSticker(sticker), to: folder.appendingPathComponent("\(sticker.name).png"))
}
print("Drew \(stickers.count + 1) stickers in \(folder.path)")
