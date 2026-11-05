import Foundation

/// The name F4 gives a sticker pasted without one (an image copied from
/// WhatsApp or a browser carries no file name): the words of the meme's
/// caption, else what the picture shows, else nil, and the caller falls
/// back to "sticker". The reading itself (Vision) happens in the app; this
/// only picks and cleans the name, so it can be tested.
public enum StickerNaming {
    /// One thing the picture shows, as Vision's classifier names it
    /// ("cat", "golden_retriever"), with how sure it is (0...1).
    public struct Label: Equatable, Sendable {
        public let identifier: String
        public let confidence: Float

        public init(identifier: String, confidence: Float) {
            self.identifier = identifier
            self.confidence = confidence
        }
    }

    /// The caption if the meme has one, else the clearest label.
    public static func name(text lines: [String], labels: [Label]) -> String? {
        caption(lines) ?? label(labels)
    }

    /// The caption's words, lower case, in reading order: punctuation and
    /// web addresses (watermarks such as "iZaping.com") dropped, cut at a
    /// word boundary after `maxLength` characters. Nil when fewer than three
    /// letters are left, which is noise rather than a caption.
    public static func caption(_ lines: [String], maxLength: Int = 48) -> String? {
        let words = lines
            .flatMap { $0.split(whereSeparator: \.isWhitespace) }
            .filter { !isWebAddress($0) }
            .map { word in
                String(word.lowercased().map { $0.isLetter || $0.isNumber || $0 == "'" || $0 == "’" ? $0 : " " })
            }
            .flatMap { $0.split(separator: " ") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'’")) }
            .filter { !$0.isEmpty }
        guard words.joined().filter(\.isLetter).count >= 3 else { return nil }
        var name = ""
        for word in words {
            let next = name.isEmpty ? word : name + " " + word
            if next.count > maxLength { break }
            name = next
        }
        return name.isEmpty ? String(words[0].prefix(maxLength)) : name
    }

    /// The most confident label that says something ("cat", not "animal"),
    /// with underscores as spaces. Nil when none reaches `minimumConfidence`.
    public static func label(_ labels: [Label], minimumConfidence: Float = 0.3) -> String? {
        labels
            .filter { $0.confidence >= minimumConfidence && !vague.contains($0.identifier) }
            .max { $0.confidence < $1.confidence }
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
    }

    /// Up to `limit` labels to tag the sticker with, most confident first,
    /// vague ones left out, underscores as spaces.
    public static func tags(_ labels: [Label], limit: Int = 3, minimumConfidence: Float = 0.3) -> [String] {
        labels
            .filter { $0.confidence >= minimumConfidence && !vague.contains($0.identifier) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(limit)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
    }

    /// Labels too broad to name a sticker by.
    static let vague: Set<String> = [
        "adult", "animal", "art", "blue_sky", "cartoon", "clothing", "container", "document",
        "drawing", "food", "furniture", "games", "illustrations", "indoor", "liquid", "machine",
        "mammal", "material", "outdoor", "people", "plant", "printed_page", "screenshot", "sign",
        "sky", "structure", "text", "tool", "toy", "vehicle", "water", "water_body",
    ]

    /// "izaping.com", "www.example.it", "https://…": a watermark, not a caption.
    static func isWebAddress<S: StringProtocol>(_ word: S) -> Bool {
        let lower = word.lowercased()
        if lower.contains("://") || lower.hasPrefix("www.") { return true }
        guard let dot = lower.lastIndex(of: "."), dot != lower.startIndex else { return false }
        let ending = lower[lower.index(after: dot)...].filter(\.isLetter)
        return (2...4).contains(ending.count) && ["com", "it", "net", "org", "io", "co", "me", "tv", "gif"].contains(String(ending))
    }
}
