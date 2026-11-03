import AppKit
import F4Core
import UniformTypeIdentifiers

/// Adds memes to the meme folder from the panel: ⌘V, a drop, or the + button.
///
/// One reader serves the clipboard and drag and drop, since both hand over
/// an `NSPasteboard`: files (Finder), promised files (apps that drag out a
/// sticker without a file on disk), raw image data (WhatsApp → Copy), and a
/// link to an image on the web, which is downloaded. The pasteboard is read
/// on the main thread; downloads and file writes happen in the background.
/// The download of a pasted or dropped link is the only request F4 makes
/// besides the update check, and only because the user asked for it.
@MainActor
enum MemeImporter {
    enum Failure: LocalizedError {
        case nothingToAdd
        case download(String)

        var errorDescription: String? {
            switch self {
            case .nothingToAdd:
                return String(localized: "F4 can only add GIF, PNG, JPEG and WebP images.")
            case .download(let reason):
                return String(localized: "Couldn't download the image: \(reason)")
            }
        }
    }

    /// Largest file F4 downloads from a link.
    private static let maxDownloadBytes = 50 * 1024 * 1024

    /// The types the panel accepts as a drop.
    static let dropTypes: [NSPasteboard.PasteboardType] = [
        .fileURL, .URL, .string, .png, .tiff,
        NSPasteboard.PasteboardType(MemeKind.gif.typeIdentifier),
        NSPasteboard.PasteboardType(MemeKind.webp.typeIdentifier),
        NSPasteboard.PasteboardType(MemeKind.jpeg.typeIdentifier),
    ] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    /// Whether ⌘V should add the clipboard instead of pasting text in the
    /// search field: there is an image or an image file, or the text is a link.
    static func canImport(_ pasteboard: NSPasteboard) -> Bool {
        let types = Set(pasteboard.types ?? [])
        if types.contains(.fileURL) || types.contains(.tiff) || types.contains(.png) { return true }
        if MemeKind.allCases.contains(where: { types.contains(NSPasteboard.PasteboardType($0.typeIdentifier)) }) { return true }
        if let string = pasteboard.string(forType: .string), MemeImport.webURL(in: string) != nil { return true }
        return false
    }

    /// Saves what the pasteboard holds into the meme folder, in the subfolder
    /// of `tab`, and returns the new files. Throws when there is nothing F4 can add.
    static func importItems(from pasteboard: NSPasteboard, into folder: URL, tab: MemeTab) async throws -> [URL] {
        // 1. Files, from Finder or any app that drags real files.
        let files = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        if !files.isEmpty {
            let saved = try await copy(files.filter { MemeKind(url: $0) != nil }, into: folder, tab: tab)
            if saved.isEmpty { throw Failure.nothingToAdd }
            return saved
        }

        // 2. Promised files: apps that drag out an image without a file yet.
        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            let received = try await receive(receivers)
            let saved = try await copy(received.filter { MemeKind(url: $0) != nil }, into: folder, tab: tab)
            if saved.isEmpty { throw Failure.nothingToAdd }
            return saved
        }

        // 3. Image data: copied from WhatsApp, a browser, Preview...
        var images: [(Data, MemeKind)] = []
        for item in pasteboard.pasteboardItems ?? [] {
            if let image = imageData(in: item) { images.append(image) }
        }
        if !images.isEmpty {
            var saved: [URL] = []
            for (data, kind) in images {
                saved.append(try await write(data, kind: kind, name: defaultName(for: kind, tab: tab), into: folder, tab: tab))
            }
            return saved
        }

        // 4. A link to an image (or a GIPHY page) on the web.
        let link = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL])?.first { !$0.isFileURL }
            ?? pasteboard.string(forType: .string).flatMap(MemeImport.webURL(in:))
        if let link {
            return [try await download(link, into: folder, tab: tab)]
        }
        throw Failure.nothingToAdd
    }

    /// Copies files picked with the + button.
    static func importFiles(_ urls: [URL], into folder: URL, tab: MemeTab) async throws -> [URL] {
        let saved = try await copy(urls.filter { MemeKind(url: $0) != nil }, into: folder, tab: tab)
        if saved.isEmpty { throw Failure.nothingToAdd }
        return saved
    }

    /// Copies a downloaded GIPHY file into the meme folder under `name`.
    static func pin(_ file: URL, name: String, into folder: URL, tab: MemeTab) async throws -> URL {
        let kind = MemeKind(url: file) ?? .gif
        let target = destination(for: kind, in: folder, tab: tab)
        return try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let url = MemeImport.uniqueURL(name: name, kind: kind, in: target)
            try FileManager.default.copyItem(at: file, to: url)
            return url
        }.value
    }

    // MARK: Reading

    /// The best image representation of one pasteboard item: the file's own
    /// format when it is one F4 keeps (a GIF stays animated), else a TIFF
    /// converted to PNG.
    private static func imageData(in item: NSPasteboardItem) -> (Data, MemeKind)? {
        for kind in [MemeKind.gif, .webp, .png, .jpeg] {
            if let data = item.data(forType: NSPasteboard.PasteboardType(kind.typeIdentifier)), !data.isEmpty {
                return (data, MemeImport.kind(sniffing: data) ?? kind)
            }
        }
        if let tiff = item.data(forType: .tiff),
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            return (png, .png)
        }
        return nil
    }

    private static func defaultName(for kind: MemeKind, tab: MemeTab) -> String {
        MemeImport.folder(for: kind, tab: tab) == MemeTab.stickersFolder
            ? String(localized: "sticker")
            : kind == .gif ? "gif" : "meme"
    }

    private static func receive(_ receivers: [NSFilePromiseReceiver]) async throws -> [URL] {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("F4-drop-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let queue = OperationQueue()
        var urls: [URL] = []
        for receiver in receivers {
            // One callback per promised file, on `queue`; collect them all.
            let collector = PromiseCollector(expected: max(receiver.fileNames.count, 1))
            urls += await withCheckedContinuation { continuation in
                collector.onDone = { continuation.resume(returning: $0) }
                receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: queue) { url, error in
                    collector.add(error == nil ? url : nil)
                }
            }
        }
        return urls
    }

    // MARK: Writing

    private static func destination(for kind: MemeKind, in folder: URL, tab: MemeTab) -> URL {
        MemeImport.folder(for: kind, tab: tab).map { folder.appendingPathComponent($0, isDirectory: true) } ?? folder
    }

    private static func copy(_ files: [URL], into folder: URL, tab: MemeTab) async throws -> [URL] {
        let jobs = files.compactMap { file in MemeKind(url: file).map { (file, $0, destination(for: $0, in: folder, tab: tab)) } }
        return try await Task.detached(priority: .userInitiated) {
            try jobs.map { file, kind, target in
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                let url = MemeImport.uniqueURL(name: file.deletingPathExtension().lastPathComponent, kind: kind, in: target)
                try FileManager.default.copyItem(at: file, to: url)
                return url
            }
        }.value
    }

    private static func write(_ data: Data, kind: MemeKind, name: String, into folder: URL, tab: MemeTab) async throws -> URL {
        let target = destination(for: kind, in: folder, tab: tab)
        return try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let url = MemeImport.uniqueURL(name: name, kind: kind, in: target)
            try data.write(to: url, options: .withoutOverwriting)
            return url
        }.value
    }

    private static func download(_ link: URL, into folder: URL, tab: MemeTab) async throws -> URL {
        let giphy = MemeImport.giphyMedia(for: link)
        let source = giphy?.url ?? link
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let data: Data
        do {
            let (body, response) = try await session.data(from: source)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw Failure.download(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
            }
            data = body
        } catch let failure as Failure {
            throw failure
        } catch {
            throw Failure.download(error.localizedDescription)
        }
        guard data.count <= maxDownloadBytes else {
            throw Failure.download(String(localized: "the file is larger than 50 MB"))
        }
        guard let kind = MemeImport.kind(sniffing: data) else { throw Failure.nothingToAdd }
        let name = giphy?.name ?? MemeImport.suggestedName(for: source)
        return try await write(data, kind: kind, name: name, into: folder, tab: tab)
    }
}

/// Gathers the files of one file promise, which arrive one callback at a time.
private final class PromiseCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var remaining: Int
    var onDone: (([URL]) -> Void)?

    init(expected: Int) {
        remaining = expected
    }

    func add(_ url: URL?) {
        lock.lock()
        if let url { urls.append(url) }
        remaining -= 1
        let done = remaining == 0 ? urls : nil
        lock.unlock()
        if let done { onDone?(done) }
    }
}
