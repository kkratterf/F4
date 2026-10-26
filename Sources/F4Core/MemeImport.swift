import Foundation

/// Where and under which name a meme added from the panel is saved.
public enum MemeImport {
    /// The kind of image in `data`, from its first bytes: a pasted or
    /// downloaded image often has no file name to go by.
    public static func kind(sniffing data: Data) -> MemeKind? {
        let bytes = [UInt8](data.prefix(12))
        func starts(_ prefix: [UInt8], at offset: Int = 0) -> Bool {
            bytes.count >= offset + prefix.count && Array(bytes[offset..<offset + prefix.count]) == prefix
        }
        if starts([0x47, 0x49, 0x46, 0x38]) { return .gif } // "GIF8"
        if starts([0x89, 0x50, 0x4E, 0x47]) { return .png } // "\u{89}PNG"
        if starts([0xFF, 0xD8, 0xFF]) { return .jpeg }
        if starts([0x52, 0x49, 0x46, 0x46]), starts([0x57, 0x45, 0x42, 0x50], at: 8) { return .webp } // "RIFF....WEBP"
        return nil
    }

    /// The kind for a pasteboard type, or nil for types F4 does not save as is.
    public static func kind(typeIdentifier: String) -> MemeKind? {
        MemeKind.allCases.first { $0.typeIdentifier == typeIdentifier }
    }

    /// The subfolder of the meme folder a new meme goes into: the one of the
    /// tab the user is in, otherwise the one its kind belongs to. JPEG memes
    /// go to the top level outside the Stickers tab.
    public static func folder(for kind: MemeKind, tab: MemeTab) -> String? {
        switch (tab, kind) {
        case (.stickers, _), (_, .png), (_, .webp): return MemeTab.stickersFolder
        case (_, .gif): return MemeTab.gifsFolder
        case (_, .jpeg): return nil
        }
    }

    /// A file name (without extension) made from `suggested`: no path
    /// separators or control characters, no leading dot (hidden files are
    /// skipped by the scan), spaces collapsed, at most `maxLength` characters.
    /// "meme" when nothing is left.
    public static func baseName(_ suggested: String, maxLength: Int = 80) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\").union(.controlCharacters).union(.newlines)
        let cleaned = suggested.unicodeScalars
            .map { forbidden.contains($0) ? " " : String($0) }
            .joined()
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
        var name = String(cleaned.drop(while: { $0 == "." || $0 == " " }).prefix(maxLength))
        while name.last == " " || name.last == "." { name.removeLast() }
        return name.isEmpty ? "meme" : name
    }

    /// `folder/name.ext`, or `name 2.ext`, `name 3.ext`... when the file is
    /// taken: an import never overwrites a meme.
    public static func uniqueURL(
        name: String,
        kind: MemeKind,
        in folder: URL,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let base = baseName(name)
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(kind.fileExtension)
        var number = 2
        while exists(candidate) {
            candidate = folder.appendingPathComponent("\(base) \(number)").appendingPathExtension(kind.fileExtension)
            number += 1
        }
        return candidate
    }

    /// The http(s) link in a pasted string, if the whole string is one.
    public static func webURL(in string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else { return nil }
        return url
    }

    /// A name for a downloaded meme: the last path component of the link
    /// without its extension ("giphy" for most GIPHY links is replaced by
    /// the host), else the host.
    public static func suggestedName(for url: URL) -> String {
        let last = url.deletingPathExtension().lastPathComponent
        let generic: Set<String> = ["", "/", "giphy", "giphy-downsized", "original", "source", "media", "image", "download"]
        if !generic.contains(last.lowercased()) { return last }
        return url.host ?? "meme"
    }
}

extension MemeKind {
    /// The extension F4 saves a file of this kind with.
    public var fileExtension: String {
        switch self {
        case .gif: return "gif"
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        }
    }
}

extension MemeImport {
    /// The GIF file behind a GIPHY page link ("giphy.com/gifs/office-wow-AbC123"
    /// or ".../stickers/..."), which is what the share button copies, plus a
    /// name made from the words of the slug. Nil for any other link.
    public static func giphyMedia(for url: URL) -> (url: URL, name: String)? {
        guard let host = url.host?.lowercased(), host == "giphy.com" || host == "www.giphy.com" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, ["gifs", "stickers", "clips"].contains(parts[0]) else { return nil }
        let words = parts[1].split(separator: "-").map(String.init)
        guard let id = words.last, !id.isEmpty, id.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        guard let media = URL(string: "https://media.giphy.com/media/\(id)/giphy.gif") else { return nil }
        let name = words.dropLast().joined(separator: " ")
        return (media, name.isEmpty ? "giphy \(id)" : name)
    }
}
