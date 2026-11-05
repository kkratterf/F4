import Foundation
import F4Core

/// Downloads a Signal sticker pack (`SignalStickerPack`): its manifest from
/// Signal's CDN, then every sticker in it, each decrypted with the pack key
/// from the link. Used by a signal.art link pasted or dropped into the panel.
enum SignalPackFetcher {
    /// Largest sticker file F4 keeps.
    private static let maxBytes = 30 * 1024 * 1024
    /// Signal packs hold at most 200 stickers.
    private static let maxStickers = 200

    enum Failure: Error {
        case manifest(String)
    }

    /// The pack's title (for its folder) and its sticker ids.
    static func manifest(of pack: SignalStickerPack, session: URLSession) async throws -> SignalStickerPack.Manifest {
        let data: Data
        do {
            data = try await download(pack.manifestURL, session: session)
        } catch {
            throw Failure.manifest(error.localizedDescription)
        }
        do {
            return try SignalStickerPack.manifest(from: pack.decrypt(data))
        } catch {
            throw Failure.manifest(String(localized: "the link's key does not open this pack"))
        }
    }

    /// Saves the stickers into `target`, skipping the ones already there
    /// (same name), and returns the files it added and how many were already
    /// there. Six downloads at a time; a sticker that fails is skipped.
    static func fetch(
        _ pack: SignalStickerPack,
        stickers: [UInt32],
        into target: URL,
        session: URLSession
    ) async -> (added: [URL], existing: Int) {
        let fileManager = FileManager.default
        let present = Set(((try? fileManager.contentsOfDirectory(atPath: target.path)) ?? [])
            .map { ($0 as NSString).deletingPathExtension })
        let ids = Array(stickers.prefix(maxStickers))
        let wanted = ids.filter { !present.contains(name(for: $0)) }
        var added: [URL] = []
        for start in stride(from: 0, to: wanted.count, by: 6) {
            let batch = Array(wanted[start..<min(start + 6, wanted.count)])
            let results = await withTaskGroup(of: (UInt32, (Data, MemeKind)?).self) { group in
                for id in batch {
                    group.addTask { (id, await sticker(pack, id: id, session: session)) }
                }
                var results: [UInt32: (Data, MemeKind)?] = [:]
                for await (id, result) in group { results[id] = result }
                return results
            }
            for id in batch {
                guard let found = results[id] ?? nil else { continue }
                let (data, kind) = found
                do {
                    try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
                    let url = MemeImport.uniqueURL(name: name(for: id), kind: kind, in: target)
                    try data.write(to: url, options: .withoutOverwriting)
                    added.append(url)
                } catch {
                    NSLog("F4: could not save Signal sticker %u: %@", id, error.localizedDescription)
                }
            }
        }
        return (added, ids.count - wanted.count)
    }

    /// "sticker_1" for the first sticker of the pack, like a getstickerpack pack.
    static func name(for id: UInt32) -> String { "sticker_\(id + 1)" }

    private static func sticker(_ pack: SignalStickerPack, id: UInt32, session: URLSession) async -> (Data, MemeKind)? {
        guard let encrypted = try? await download(pack.stickerURL(id), session: session),
              let data = try? pack.decrypt(encrypted),
              data.count <= maxBytes,
              let kind = MemeImport.kind(sniffing: data)
        else { return nil }
        return (data, kind)
    }

    private static func download(_ url: URL, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
