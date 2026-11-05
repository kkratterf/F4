import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import F4Core

final class StickerConverterTests: XCTestCase {
    func testFitKeepsProportionsAndCentres() {
        let wide = StickerConverter.fit(width: 2000, height: 1000)
        XCTAssertEqual(wide.width, 512, accuracy: 0.001)
        XCTAssertEqual(wide.height, 256, accuracy: 0.001)
        XCTAssertEqual(wide.midX, 256, accuracy: 0.001)
        XCTAssertEqual(wide.midY, 256, accuracy: 0.001)
        let tall = StickerConverter.fit(width: 10, height: 20)
        XCTAssertEqual(tall.height, 512, accuracy: 0.001)
        XCTAssertEqual(tall.width, 256, accuracy: 0.001)
        XCTAssertEqual(StickerConverter.fit(width: 0, height: 10), .zero)
    }

    /// A meme (an opaque picture, text and all) becomes a 512 square with
    /// the whole picture in it and transparent bands where it doesn't fill it.
    func testAPictureBecomesASquareSticker() throws {
        let meme = try png(drawing: 1200, 800, opaque: true) { context in
            context.setFillColor(CGColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
            context.setFillColor(CGColor(red: 1, green: 0.8, blue: 0.2, alpha: 1))
            context.fillEllipse(in: CGRect(x: 400, y: 200, width: 400, height: 400))
            // The caption, edge to edge: it must survive.
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 120))
        }
        let sticker = try XCTUnwrap(StickerConverter.sticker(from: meme))
        let image = try decode(sticker)
        XCTAssertEqual(image.width, 512)
        XCTAssertEqual(image.height, 512)
        // 1200×800 fits as 512×341: transparent bands above and below.
        XCTAssertEqual(try alpha(of: image, x: 256, y: 10), 0)
        XCTAssertEqual(try alpha(of: image, x: 256, y: 500), 0)
        XCTAssertEqual(try alpha(of: image, x: 256, y: 256), 255)
        // The whole width is kept, caption corners included.
        XCTAssertEqual(try alpha(of: image, x: 1, y: 256), 255)
        XCTAssertEqual(try alpha(of: image, x: 510, y: 256), 255)
        try keep(meme, as: "converter-original.png")
        try keep(sticker, as: "converter-sticker.png")
    }

    /// A sticker that is already transparent is kept exactly as it is.
    func testATransparentStickerIsKept() throws {
        let sticker = try png(drawing: 300, 300, opaque: false) { context in
            context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1))
            context.fillEllipse(in: CGRect(x: 20, y: 20, width: 260, height: 260))
        }
        XCTAssertNil(StickerConverter.sticker(from: sticker))
    }

    func testLeavesAnimatedImagesAlone() throws {
        let frame = try XCTUnwrap(cgImage(width: 20, height: 20, opaque: true) { context in
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        })
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 2, nil))
        CGImageDestinationAddImage(destination, frame, nil)
        CGImageDestinationAddImage(destination, frame, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        XCTAssertNil(StickerConverter.sticker(from: data as Data))
        XCTAssertNil(StickerConverter.sticker(from: Data("not an image".utf8)))
    }

    // MARK: Helpers

    private func cgImage(width: Int, height: Int, opaque: Bool, draw: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue
        ) else { return nil }
        draw(context)
        return context.makeImage()
    }

    private func png(drawing width: Int, _ height: Int, opaque: Bool, draw: (CGContext) -> Void) throws -> Data {
        let image = try XCTUnwrap(cgImage(width: width, height: height, opaque: opaque, draw: draw))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func decode(_ data: Data) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    /// The alpha of every pixel, row by row from the top left.
    private func alphas(of image: CGImage) throws -> [UInt8] {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    private func alpha(of image: CGImage, x: Int, y: Int) throws -> UInt8 {
        try alphas(of: image)[y * image.width + x]
    }

    /// CI sets F4_STICKER_PREVIEW to keep the stickers, so they can be looked at.
    private func keep(_ data: Data, as name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["F4_STICKER_PREVIEW"] else { return }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name))
    }
}
