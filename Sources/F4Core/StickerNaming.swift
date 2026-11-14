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

    /// Whether a file name (without its extension) says nothing about the
    /// sticker, so F4 names it after what it reads on the picture instead:
    /// what WhatsApp, cameras, screenshots and browsers call a file
    /// ("WhatsApp Image 2026-11-14 at 20.12.03", "STK-20231105-WA0003",
    /// "IMG_1234", "Screenshot 2026-11-14 alle 21.03", "image (2)",
    /// "sticker_7"), a hash or a UUID, or no letters at all. A name with
    /// one real word in it ("boh", "cat 2") is kept.
    public static func isGenericFileName(_ name: String) -> Bool {
        let words = name.lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .filter { word in
                // A word with a digit is a counter, a date, a hash or "wa0003".
                !word.contains(where: \.isNumber) && word.count > 1 && !genericWords.contains(String(word))
            }
        return words.isEmpty
    }

    /// Words of the names apps give files, in English and Italian.
    static let genericWords: Set<String> = [
        "whatsapp", "telegram", "signal", "wa", "tg", "stk", "img", "image", "images", "immagine",
        "photo", "foto", "pic", "picture", "sticker", "stickers", "screenshot", "screen", "shot",
        "schermata", "untitled", "senza", "titolo", "unnamed", "download", "file", "pasted",
        "graphic", "clipboard", "copy", "copia", "at", "alle", "dsc", "pxl", "giphy", "tenor",
        "gif", "webp", "png", "jpg", "jpeg", "animated", "media", "new", "nuovo",
    ]

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
