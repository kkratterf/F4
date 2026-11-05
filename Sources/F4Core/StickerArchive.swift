import Foundation

/// A WhatsApp sticker pack file (`.wastickers`): a zip with the stickers as
/// WebP files, a `title.txt` and an `author.txt`, and a small PNG tray icon.
/// Dropping one on the panel, or adding it with ⌘V or Add, turns it into a
/// folder of the library named after the pack.
public enum StickerArchive {
    /// File extensions F4 opens as a sticker pack.
    public static let extensions: Set<String> = ["wastickers", "zip"]

    public static func isArchive(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }

    /// The folder name for a pack: the first line of `title.txt` when there
    /// is one, else the archive's name ("Boris.wastickers" → "Boris").
    public static func folderName(title: String?, archive: URL) -> String {
        let firstLine = title?
            .split(whereSeparator: \.isNewline).first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        if let firstLine, let name = LibraryFolders.folderName(firstLine) { return name }
        return LibraryFolders.folderName(archive.deletingPathExtension().lastPathComponent) ?? "Stickers"
    }

    /// The stickers to keep among the archive's files (paths relative to
    /// where it was unpacked): the images, without the tray icon (a PNG
    /// named "tray…", or any PNG when the pack has WebP stickers), hidden
    /// files and macOS's `__MACOSX` copies.
    public static func stickers(in files: [String]) -> [String] {
        let images = files.filter { path in
            let parts = path.split(separator: "/")
            guard let name = parts.last, !name.hasPrefix("."), !parts.contains("__MACOSX") else { return false }
            return MemeKind(url: URL(fileURLWithPath: path)) != nil
        }
        let hasWebP = images.contains { $0.lowercased().hasSuffix(".webp") }
        return images.filter { path in
            let file = (path as NSString).lastPathComponent.lowercased()
            if file.hasPrefix("tray") { return false }
            if hasWebP && file.hasSuffix(".png") { return false }
            return true
        }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
