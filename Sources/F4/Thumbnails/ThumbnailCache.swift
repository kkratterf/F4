import CoreGraphics
import F4Core
import Foundation
import ImageIO

/// Downscaled, static thumbnails of memes, decoded off the main thread and
/// kept in memory.
///
/// ImageIO decodes straight to the target size (`kCGImageSourceThumbnailMaxPixelSize`),
/// so a 20 MB GIF costs a few KB of memory and never a full decode. GIFs give
/// their first frame: the grid never plays dozens of animations at once.
/// The key includes the modification date, so an edited file is decoded again.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, CGImage>()

    init(costLimit: Int = 64 * 1024 * 1024) {
        // Cost = decoded bytes; NSCache evicts under memory pressure as well.
        cache.totalCostLimit = costLimit
    }

    /// The cached thumbnail, if any. Cheap: safe to call from a view body.
    func cached(_ meme: Meme, maxPixelSize: Int) -> CGImage? {
        cache.object(forKey: key(meme, maxPixelSize))
    }

    /// The thumbnail, decoding it in the background on a cache miss.
    func thumbnail(for meme: Meme, maxPixelSize: Int) async -> CGImage? {
        let key = key(meme, maxPixelSize)
        if let image = cache.object(forKey: key) { return image }
        let url = meme.url
        let image = await Task.detached(priority: .userInitiated) {
            Self.decode(url: url, maxPixelSize: maxPixelSize)
        }.value
        if let image {
            cache.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
        }
        return image
    }

    private func key(_ meme: Meme, _ maxPixelSize: Int) -> NSString {
        "\(meme.url.path)|\(meme.modificationDate.timeIntervalSince1970)|\(maxPixelSize)" as NSString
    }

    private static func decode(url: URL, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        // Index 0: the first frame of a GIF.
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
