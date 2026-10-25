import Foundation

/// Lists the memes in a folder.
public enum MemeScanner {
    /// `~/Pictures/Memes`, used until the user picks another folder.
    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("Memes", isDirectory: true)
    }

    /// The GIF, PNG and JPEG files directly inside `folder`, sorted by name the
    /// way Finder sorts them. Hidden files, folders and other file types are
    /// skipped. Blocking: call it off the main thread.
    public static func scan(folder: URL, fileManager: FileManager = .default) throws -> [Meme] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        let urls = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageContents, .skipsSubdirectoryDescendants]
        )
        var memes: [Meme] = []
        for url in urls {
            guard let kind = MemeKind(url: url) else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile ?? false else { continue }
            memes.append(Meme(url: url, kind: kind, modificationDate: values?.contentModificationDate ?? .distantPast))
        }
        return memes.sorted { lhs, rhs in
            let order = lhs.name.localizedStandardCompare(rhs.name)
            if order == .orderedSame { return lhs.url.lastPathComponent < rhs.url.lastPathComponent }
            return order == .orderedAscending
        }
    }
}
