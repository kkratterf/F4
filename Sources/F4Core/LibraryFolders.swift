import Foundation

/// Where the meme library lives, and the names and paths F4 uses when the
/// user organizes it from the panel or the menu (new folder, move, rename).
public enum LibraryFolders {
    /// `~/Library/Application Support/F4/Memes`: F4's own library, the
    /// default since 0.4. F4 copies the starter pack into it once, so a new
    /// user starts with memes that are ordinary files to move or delete.
    public static func appLibrary(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("F4", isDirectory: true)
            .appendingPathComponent("Memes", isDirectory: true)
    }

    /// `~/Pictures/Memes`, the default before 0.4.
    public static func legacyFolder(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("Memes", isDirectory: true)
    }

    /// The folder to read at launch: the one the user picked, else
    /// `~/Pictures/Memes` when it already holds memes (someone upgrading from
    /// a version that used it by default), else F4's own library.
    /// `persist` is true when the choice should be saved, so a later empty
    /// `~/Pictures/Memes` does not switch the user to another library.
    public static func initialFolder(
        savedPath: String?,
        legacyHasMemes: Bool,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> (url: URL, persist: Bool) {
        if let savedPath, !savedPath.isEmpty {
            return (URL(fileURLWithPath: savedPath, isDirectory: true), false)
        }
        if legacyHasMemes {
            return (legacyFolder(home: home), true)
        }
        return (appLibrary(home: home), false)
    }

    /// A folder name typed by the user, cleaned like a file name (no `/`,
    /// `:` or leading dot, spaces collapsed), or nil when nothing is left.
    public static func folderName(_ typed: String, maxLength: Int = 60) -> String? {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let name = MemeImport.baseName(trimmed, maxLength: maxLength)
        // baseName falls back to "meme" when it strips everything.
        if name == "meme" && trimmed.lowercased() != "meme" { return nil }
        return name
    }

    /// `folder/base.ext`, or `base 2.ext`, `base 3.ext`... when taken: moving
    /// or renaming a meme never overwrites another one.
    public static func uniqueFile(
        base: String,
        pathExtension: String,
        in folder: URL,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let base = MemeImport.baseName(base)
        func candidate(_ name: String) -> URL {
            let url = folder.appendingPathComponent(name)
            return pathExtension.isEmpty ? url : url.appendingPathExtension(pathExtension)
        }
        var url = candidate(base)
        var number = 2
        while exists(url) {
            url = candidate("\(base) \(number)")
            number += 1
        }
        return url
    }

    /// The URL of a category ("reactions/dogs") in the library, or the library
    /// itself for nil.
    public static func url(of category: String?, in library: URL) -> URL {
        guard let category, !category.isEmpty else { return library }
        return category.split(separator: "/").reduce(library) {
            $0.appendingPathComponent(String($1), isDirectory: true)
        }
    }

    /// The starter files (paths relative to the starter folder, e.g.
    /// "GIFs/clown.gif") still to copy into the library: those whose path is
    /// not taken there yet, so seeding twice never duplicates or overwrites.
    public static func starterFilesToCopy(_ starter: [String], existing: Set<String>) -> [String] {
        starter.filter { !existing.contains($0) }
    }

    /// `path` with the prefix `old` replaced by `new`, or nil when `path` is
    /// neither `old` nor inside it: how favourites and recents follow a meme
    /// or a folder that was moved or renamed.
    public static func relocatedPath(_ path: String, from old: String, to new: String) -> String? {
        if path == old { return new }
        guard path.hasPrefix(old + "/") else { return nil }
        return new + path.dropFirst(old.count)
    }
}
