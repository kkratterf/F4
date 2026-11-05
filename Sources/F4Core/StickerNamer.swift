import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Reads a pasted picture on the Mac, with Vision, to name it: the text of
/// the meme's caption, else what it shows (`StickerNaming` picks). Nothing
/// leaves the Mac. Blocking: call it off the main thread.
public enum StickerNamer {
    /// What a picture says about itself: a name (nil when nothing is read)
    /// and tags for what it shows.
    public struct Reading: Equatable, Sendable {
        public let name: String?
        public let tags: [String]
    }

    /// The name only.
    public static func name(for data: Data) -> String? {
        reading(for: data)?.name
    }

    /// The name and the tags, or nil when `data` is not a picture.
    public static func reading(for data: Data) -> Reading? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1024,
              ] as CFDictionary)
        else { return nil }
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        let supported = (try? text.supportedRecognitionLanguages()) ?? []
        text.recognitionLanguages = ["it-IT", "en-US"].filter(supported.contains)
        let classify = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        // Each request reports its own failure; one failing leaves the other.
        try? handler.perform([text])
        try? handler.perform([classify])
        // Reading order: top to bottom (Vision's origin is bottom left), then left to right.
        let lines = (text.results ?? [])
            .sorted { lhs, rhs in
                abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.02
                    ? lhs.boundingBox.midY > rhs.boundingBox.midY
                    : lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            .compactMap { $0.topCandidates(1).first }
            .filter { $0.confidence >= 0.5 }
            .map(\.string)
        let labels = (classify.results ?? []).map {
            StickerNaming.Label(identifier: $0.identifier, confidence: $0.confidence)
        }
        return Reading(name: StickerNaming.name(text: lines, labels: labels), tags: StickerNaming.tags(labels))
    }
}
