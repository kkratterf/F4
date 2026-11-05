import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns a picture into a meme sticker: the whole picture, text and all,
/// fitted into a 512×512 square (the size WhatsApp uses), with the space
/// left over transparent. Nothing is cut out and nothing is added.
///
/// An image that is already transparent (a sticker, a cut-out PNG) and an
/// animated one are left exactly as they are: `sticker(from:)` returns nil.
public enum StickerConverter {
    /// Pixels on each side of a sticker.
    public static let side = 512

    /// The sticker as PNG data, or nil when the image should be kept as it
    /// is (transparent, animated, or unreadable). Call it off the main thread.
    public static func sticker(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: side * 2,
              ] as CFDictionary),
              !hasTransparency(image)
        else { return nil }
        return render(image)
    }

    /// Where a `width`×`height` picture goes in the square: as large as
    /// fits, keeping its proportions, centred.
    public static func fit(width: CGFloat, height: CGFloat) -> CGRect {
        let room = CGFloat(side)
        guard width > 0, height > 0 else { return .zero }
        let scale = min(room / width, room / height)
        let size = CGSize(width: width * scale, height: height * scale)
        return CGRect(
            x: (room - size.width) / 2,
            y: (room - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Whether the image has see-through pixels, looked at on a small copy.
    static func hasTransparency(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let size = 32
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.clear(CGRect(x: 0, y: 0, width: size, height: size))
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else { return false }
        return stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] < 250 }
    }

    /// The picture fitted into a transparent square, as PNG.
    static func render(_ image: CGImage) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: side, height: side))
        context.draw(image, in: fit(width: CGFloat(image.width), height: CGFloat(image.height)))
        guard let square = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, square, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
