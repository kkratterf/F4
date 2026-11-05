import AppKit
import F4Core

/// What the user can do to a meme from its right-click menu in the panel.
enum MemeAction {
    /// Into a folder of the library ("reactions/dogs"), or its top level for nil.
    case move(to: String?)
    /// Into a new folder, named in a prompt.
    case moveToNewFolder
    case rename
    case trash
}

/// Organizes the meme folder from the UI, so the user never needs Finder:
/// new folders, moving and renaming memes, renaming folders, and moving
/// either to the Trash (never a permanent delete).
///
/// Every change is a plain file operation in the meme folder; favourites and
/// recents follow the files, and the library rescans afterwards (the folder
/// watcher would too, a moment later). Names are typed in a small prompt.
@MainActor
final class LibraryOrganizer {
    private let library: MemeLibrary
    private let usage: UsageStore

    init(library: MemeLibrary, usage: UsageStore) {
        self.library = library
        self.usage = usage
    }

    /// Runs `action` on `meme`. Returns a message for the panel's notice
    /// line, or nil when the user cancelled.
    @discardableResult
    func perform(_ action: MemeAction, on meme: Meme) -> String? {
        do {
            switch action {
            case .move(let category):
                return try move(meme, to: category)
            case .moveToNewFolder:
                guard let category = try newFolder() else { return nil }
                return try move(meme, to: category)
            case .rename:
                return try rename(meme)
            case .trash:
                try trash(meme.url)
                return String(localized: "Moved \(meme.name) to the Trash")
            }
        } catch {
            return error.localizedDescription
        }
    }

    /// "New Folder…": asks for a name and creates the folder at the top of
    /// the library. Returns its category, or nil when cancelled.
    @discardableResult
    func newFolder() throws -> String? {
        guard let typed = prompt(
            title: String(localized: "New Folder"),
            message: String(localized: "Folders work as categories: search finds a sticker by its folder too."),
            value: "",
            confirm: String(localized: "Create")
        ), let name = LibraryFolders.folderName(typed) else { return nil }
        let url = LibraryFolders.uniqueFile(base: name, pathExtension: "", in: library.folder)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        library.reload()
        return url.lastPathComponent
    }

    /// "Rename…" on a folder of the library.
    func renameFolder(_ category: String) {
        let url = LibraryFolders.url(of: category, in: library.folder)
        guard let typed = prompt(
            title: String(localized: "Rename Folder"),
            message: nil,
            value: url.lastPathComponent,
            confirm: String(localized: "Rename")
        ), let name = LibraryFolders.folderName(typed), name != url.lastPathComponent else { return }
        let destination = LibraryFolders.uniqueFile(base: name, pathExtension: "", in: url.deletingLastPathComponent())
        do {
            try FileManager.default.moveItem(at: url, to: destination)
            usage.relocate(from: url, to: destination)
            library.reload()
        } catch {
            show(error)
        }
    }

    /// "Move to Trash" on a folder of the library, after a confirmation
    /// that says how many memes go with it.
    func trashFolder(_ category: String) {
        let url = LibraryFolders.url(of: category, in: library.folder)
        trashFolders([category], named: url.lastPathComponent)
    }

    /// Moves `categories` to the Trash after one confirmation, titled with
    /// `name`: a folder, or a pack's GIFs and Stickers folders. Returns
    /// false when the user cancelled.
    @discardableResult
    func trashFolders(_ categories: [String], named name: String) -> Bool {
        let urls = categories.map { LibraryFolders.url(of: $0, in: library.folder) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        let count = library.memes.filter { meme in
            categories.contains { meme.category == $0 || meme.category?.hasPrefix($0 + "/") == true }
        }.count
        let alert = NSAlert()
        alert.messageText = String(localized: "Move “\(name)” to the Trash?")
        alert.informativeText = count == 1
            ? String(localized: "The sticker in it goes too. You can put it back from the Trash.")
            : String(localized: "The \(String(count)) stickers in it go too. You can put them back from the Trash.")
        alert.addButton(withTitle: String(localized: "Move to Trash"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard run(alert) == .alertFirstButtonReturn else { return false }
        do {
            for url in urls { try trash(url) }
        } catch {
            show(error)
        }
        return true
    }

    // MARK: Memes

    private func move(_ meme: Meme, to category: String?) throws -> String {
        let folder = LibraryFolders.url(of: category, in: library.folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = LibraryFolders.uniqueFile(
            base: meme.name,
            pathExtension: meme.url.pathExtension,
            in: folder
        )
        try FileManager.default.moveItem(at: meme.url, to: destination)
        usage.relocate(from: meme.url, to: destination)
        library.reload()
        return category.map { String(localized: "Moved to \($0)") } ?? String(localized: "Moved to the top level")
    }

    private func rename(_ meme: Meme) throws -> String? {
        guard let typed = prompt(
            title: String(localized: "Rename Sticker"),
            message: String(localized: "Search finds a sticker by its name, so name it the way you will look for it."),
            value: meme.name,
            confirm: String(localized: "Rename")
        ) else { return nil }
        let name = MemeImport.baseName(typed)
        guard name != meme.name else { return nil }
        let destination = LibraryFolders.uniqueFile(
            base: name,
            pathExtension: meme.url.pathExtension,
            in: meme.url.deletingLastPathComponent()
        )
        try FileManager.default.moveItem(at: meme.url, to: destination)
        usage.relocate(from: meme.url, to: destination)
        library.reload()
        return String(localized: "Renamed to \(destination.deletingPathExtension().lastPathComponent)")
    }

    private func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        usage.forget(url)
        library.reload()
    }

    // MARK: Prompts

    /// A small alert with a text field. Nil when cancelled.
    private func prompt(title: String, message: String?, value: String, confirm: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        if let message { alert.informativeText = message }
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.window.initialFirstResponder = field
        return run(alert) == .alertFirstButtonReturn ? field.stringValue : nil
    }

    private func show(_ error: Error) {
        let alert = NSAlert(error: error)
        _ = run(alert)
    }

    /// F4 is an accessory app and the panel floats: the alert comes to the
    /// front above both.
    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .modalPanel
        return alert.runModal()
    }
}
