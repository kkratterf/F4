import Foundation

/// Lists the memes in a folder and its subfolders.
public enum MemeScanner {
    /// `~/Pictures/Memes`, used until the user picks another folder.
    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("Memes", isDirectory: true)
    }

    /// How deep subfolders are scanned (the folder itself is depth 0).
    public static let maxDepth = 4

    /// The GIF, PNG, JPEG and WebP files in `folder` and its subfolders (up to
    /// `maxDepth`), each subfolder becoming the meme's category. Top-level
    /// memes come first, then each subfolder; names are sorted the way Finder
    /// sorts them. Hidden files and folders, packages and other file types are
    /// skipped. Blocking: call it off the main thread.
    public static func scan(folder: URL, fileManager: FileManager = .default) throws -> [Meme] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey]
        // contentsOfDirectory throws for a missing or unreadable folder; the
        // enumerator would silently return nothing.
        _ = try fileManager.contentsOfDirectory(atPath: folder.path)
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let root = folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        var memes: [Meme] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                if enumerator.level > maxDepth { enumerator.skipDescendants() }
                continue
            }
            guard values?.isRegularFile == true, let kind = MemeKind(url: url) else { continue }
            let parent = url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().pathComponents
            let category = parent.count > root.count ? parent[root.count...].joined(separator: "/") : nil
            memes.append(Meme(
                url: url,
                kind: kind,
                modificationDate: values?.contentModificationDate ?? .distantPast,
                category: category
            ))
        }
        return memes.sorted(by: finderOrder)
    }

    private static func finderOrder(_ lhs: Meme, _ rhs: Meme) -> Bool {
        if lhs.category != rhs.category {
            guard let left = lhs.category else { return true }
            guard let right = rhs.category else { return false }
            return left.localizedStandardCompare(right) == .orderedAscending
        }
        let order = lhs.name.localizedStandardCompare(rhs.name)
        if order == .orderedSame { return lhs.url.lastPathComponent < rhs.url.lastPathComponent }
        return order == .orderedAscending
    }
}
