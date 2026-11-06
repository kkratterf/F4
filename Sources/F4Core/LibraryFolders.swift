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
    public static func starterFilesToCopy(_ starter: [String], existing: Set<String>, seeded: Set<String> = []) -> [String] {
        starter.filter { !existing.contains($0) && !seeded.contains(topFolder(of: $0)) }
    }

    /// The top-level starter folders copied by F4 up to 0.4, before it
    /// kept a list of them (`didSeedLibrary` was a single flag).
    public static let firstStarterFolders: Set<String> = ["Emoji", "F4"]

    /// The starter folders F4 copied into its library up to 0.6 and no
    /// longer ships: since 0.7 the starter pack is maramao alone (the
    /// maintainer's call).
    public static let retiredStarterFolders: Set<String> = ["Emoji", "F4"]

    /// The files those folders held, relative to the library. F4 moves to
    /// the Trash only these, where they still are, and then a retired
    /// folder left empty: a sticker the user added there stays.
    public static let retiredStarterFiles: [String] = {
        let emoji: [String] = [
            "100", "broken heart", "clap applause", "clown", "cool sunglasses", "crying sob",
            "eye roll", "eyes", "fire", "grimace yikes", "heart eyes love", "melting",
            "mind blown", "nerd actually", "party", "pleading puppy eyes", "please thank you",
            "rolling on the floor laughing", "salute", "scream shock", "skull dead",
            "sweat smile awkward", "tada congrats", "tears of joy", "thinking hmm", "thumbs up ok",
        ]
        let drawn: [String] = [
            "f4 keycap", "basito", "dai dai dai", "smarmella", "apri tutto", "lol", "nope", "same",
            "plus one", "ship it", "big mood", "bruh", "wow",
        ]
        return emoji.map { "Emoji/\($0).gif" } + drawn.map { "F4/\($0).png" }
    }()

    /// The top-level folder of a path relative to the starter pack
    /// ("maramao/boh.png" is in "maramao"); a file at the top is its own.
    public static func topFolder(of path: String) -> String {
        path.split(separator: "/", maxSplits: 1).first.map(String.init) ?? path
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
