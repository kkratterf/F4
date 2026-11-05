import Foundation

/// Links to a sticker pack on getstickerpack.com, the site behind the
/// "Sticker Maker" apps people use to add packs to WhatsApp: the pack page
/// (`https://getstickerpack.com/stickers/memes-19`), the long link its
/// "Add to WhatsApp" button opens (`https://preview.page.link/...?link=...`)
/// or one of its sticker files. The files of a pack live at
/// `https://s3.getstickerpack.com/storage/uploads/sticker-pack/<pack>/sticker_<n>.png`,
/// numbered from 1, so F4 downloads them one after the other until one is
/// missing. Nothing here touches the network.
public enum StickerPackLink {
    /// The most stickers F4 tries for one pack (WhatsApp packs hold 30).
    public static let maxStickers = 60

    /// The pack a link points to ("memes-19"), or nil when it is not a
    /// getstickerpack link.
    public static func slug(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        if host == "getstickerpack.com" || host == "www.getstickerpack.com" {
            guard parts.count >= 2, parts[0].lowercased() == "stickers" else { return nil }
            return clean(parts[1])
        }
        if host == "s3.getstickerpack.com" {
            guard let index = parts.firstIndex(of: "sticker-pack"), index + 1 < parts.count else { return nil }
            return clean(parts[index + 1])
        }
        if host.hasSuffix(".page.link") || host == "page.link",
           let inner = query(url, "link").flatMap(URL.init(string:)), inner.host?.hasSuffix("page.link") != true {
            return slug(from: inner)
        }
        return nil
    }

    /// The pack's title when the link carries it (the app link's `st`,
    /// "memes gatos").
    public static func title(from url: URL) -> String? {
        // Query strings write spaces as "+", which URLComponents keeps.
        query(url, "st")
            .map { $0.replacingOccurrences(of: "+", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The library folder a pack goes into: its title, else its slug.
    public static func folderName(slug: String, title: String?) -> String {
        title.flatMap { LibraryFolders.folderName($0) } ?? LibraryFolders.folderName(slug) ?? "Stickers"
    }

    /// The links to try for sticker `index` (from 1): PNG first, then WebP.
    public static func stickerURLs(slug: String, index: Int) -> [URL] {
        ["png", "webp"].compactMap {
            URL(string: "https://s3.getstickerpack.com/storage/uploads/sticker-pack/\(slug)/sticker_\(index).\($0)")
        }
    }

    /// The file name F4 gives sticker `index` ("sticker_1").
    public static func stickerName(index: Int) -> String { "sticker_\(index)" }

    /// "memes-19!y3r631" → "memes-19": the app link adds a code after "!".
    private static func clean(_ component: String) -> String? {
        let slug = component.split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard !slug.isEmpty, slug.unicodeScalars.allSatisfy(allowed.contains), !slug.hasPrefix(".") else { return nil }
        return slug
    }

    private static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}
