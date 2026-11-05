import Foundation
import F4Core

/// Downloads a getstickerpack pack (`StickerPackLink`): sticker_1,
/// sticker_2... one after the other, until one is missing. Used by a link
/// pasted or dropped into the panel and by the packs of the menu bar's Packs.
enum StickerPackFetcher {
    /// Largest sticker file F4 keeps.
    private static let maxBytes = 30 * 1024 * 1024

    /// Saves the pack's stickers into `target`, skipping the ones already
    /// there (same name), and returns the files it added and how many were
    /// already there. Six downloads at a time; it stops at the first sticker
    /// that is not on the server.
    static func fetch(slug: String, into target: URL, session: URLSession) async -> (added: [URL], existing: Int) {
        let fileManager = FileManager.default
        let present = Set(((try? fileManager.contentsOfDirectory(atPath: target.path)) ?? [])
            .map { ($0 as NSString).deletingPathExtension })
        var added: [URL] = []
        var existing = 0
        for first in stride(from: 1, through: StickerPackLink.maxStickers, by: 6) {
            let indices = Array(first...min(first + 5, StickerPackLink.maxStickers))
            let wanted = indices.filter { !present.contains(StickerPackLink.stickerName(index: $0)) }
            existing += indices.count - wanted.count
            let results = await withTaskGroup(of: (Int, (Data, MemeKind)?).self) { group in
                for index in wanted {
                    group.addTask { (index, await sticker(slug: slug, index: index, session: session)) }
                }
                var results: [Int: (Data, MemeKind)?] = [:]
                for await (index, result) in group { results[index] = result }
                return results
            }
            for index in wanted {
                guard let found = results[index] ?? nil else { return (added, existing) }
                let (data, kind) = found
                do {
                    try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
                    let url = MemeImport.uniqueURL(name: StickerPackLink.stickerName(index: index), kind: kind, in: target)
                    try data.write(to: url, options: .withoutOverwriting)
                    added.append(url)
                } catch {
                    NSLog("F4: could not save sticker %d of %@: %@", index, slug, error.localizedDescription)
                    return (added, existing)
                }
            }
        }
        return (added, existing)
    }

    /// Sticker `index`, as PNG or else WebP; nil when the server has neither.
    private static func sticker(slug: String, index: Int, session: URLSession) async -> (Data, MemeKind)? {
        for url in StickerPackLink.stickerURLs(slug: slug, index: index) {
            guard let reply = try? await session.data(from: url) else { continue }
            let (data, response) = reply
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { continue }
            if data.count <= maxBytes, let kind = MemeImport.kind(sniffing: data) { return (data, kind) }
        }
        return nil
    }
}
