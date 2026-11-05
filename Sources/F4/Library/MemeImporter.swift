import AppKit
import F4Core
import UniformTypeIdentifiers

/// Adds stickers to the library from the panel: ⌘V, a drop, or the + button.
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
        case packAlreadyAdded(String)

        var errorDescription: String? {
            switch self {
            case .nothingToAdd:
                return String(localized: "F4 can only add GIF, PNG, JPEG and WebP images, and WhatsApp sticker packs (.wastickers).")
            case .download(let reason):
                return String(localized: "Couldn't download the image: \(reason)")
            case .packAlreadyAdded(let folder):
                return String(localized: "You already have every sticker of \(folder).")
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

    /// Saves what the pasteboard holds into `folder` (the top of the
    /// library) and returns the new files. Throws when there is nothing F4
    /// can add. With `convert`, a still PNG or JPEG becomes a sticker
    /// (`StickerConverter`): ⌥⌘V passes false to keep the image as it is.
    static func importItems(from pasteboard: NSPasteboard, into folder: URL, convert: Bool = true) async throws -> [URL] {
        // 1. Files, from Finder or any app that drags real files.
        let files = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        if !files.isEmpty {
            let saved = try await copy(files.filter(isImportable), into: folder, convert: convert)
            if saved.isEmpty { throw Failure.nothingToAdd }
            return saved
        }

        // 2. Promised files: apps that drag out an image without a file yet.
        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            let received = try await receive(receivers)
            let saved = try await copy(received.filter(isImportable), into: folder, convert: convert)
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
                // A copied image has no file name: read one off the picture.
                saved.append(try await write(data, kind: kind, name: nil, into: folder, convert: convert))
            }
            return saved
        }

        // 4. A link to an image or a sticker pack file on the web.
        let link = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL])?.first { !$0.isFileURL }
            ?? pasteboard.string(forType: .string).flatMap(MemeImport.webURL(in:))
        if let link {
            return try await download(link, into: folder, convert: convert)
        }
        throw Failure.nothingToAdd
    }

    /// Copies files picked with the + button.
    static func importFiles(_ urls: [URL], into folder: URL) async throws -> [URL] {
        let saved = try await copy(urls.filter(isImportable), into: folder, convert: true)
        if saved.isEmpty { throw Failure.nothingToAdd }
        return saved
    }

    /// An image F4 keeps as a sticker, or a sticker pack file (`.wastickers`).
    private static func isImportable(_ url: URL) -> Bool {
        MemeKind(url: url) != nil || StickerArchive.isArchive(url)
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

    private static func copy(_ files: [URL], into folder: URL, convert: Bool) async throws -> [URL] {
        let jobs = files.compactMap { file in MemeKind(url: file).map { (file, $0, folder) } }
        let archives = files.filter(StickerArchive.isArchive)
        return try await Task.detached(priority: .userInitiated) {
            let copied = try jobs.map { file, kind, target in
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                let name = file.deletingPathExtension().lastPathComponent
                if convert, Self.isConvertible(kind), let data = try? Data(contentsOf: file),
                   let sticker = StickerConverter.sticker(from: data) {
                    let url = MemeImport.uniqueURL(name: name, kind: .png, in: target)
                    try sticker.write(to: url, options: .withoutOverwriting)
                    return url
                }
                let url = MemeImport.uniqueURL(name: name, kind: kind, in: target)
                try FileManager.default.copyItem(at: file, to: url)
                return url
            }
            return try copied + archives.flatMap { try unpack($0, into: folder) }
        }.value
    }

    /// Saves `data` in `folder` as `name`, or, when `name` is nil, as what
    /// `StickerNamer` reads on the picture (its caption, or what it shows),
    /// and "sticker" when it reads nothing.
    private static func write(_ data: Data, kind: MemeKind, name: String?, into folder: URL, convert: Bool) async throws -> URL {
        let target = folder
        let fallback = String(localized: "sticker")
        return try await Task.detached(priority: .userInitiated) {
            let name = name ?? StickerNamer.name(for: data).map { MemeImport.baseName($0) } ?? fallback
            var (data, kind) = (data, kind)
            if convert, Self.isConvertible(kind), let sticker = StickerConverter.sticker(from: data) {
                (data, kind) = (sticker, .png)
            }
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let url = MemeImport.uniqueURL(name: name, kind: kind, in: target)
            try data.write(to: url, options: .withoutOverwriting)
            return url
        }.value
    }

    /// Still images the converter turns into stickers. GIFs and WebP
    /// (WhatsApp's own sticker format, often animated) stay as they are.
    nonisolated private static func isConvertible(_ kind: MemeKind) -> Bool {
        kind == .png || kind == .jpeg
    }

    /// Unpacks a sticker pack file into a folder of the library named after
    /// the pack, and returns the stickers it added. Blocking: off the main thread.
    nonisolated private static func unpack(_ archive: URL, into folder: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory
            .appendingPathComponent("F4-pack-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporary) }
        // ditto ships with macOS and unpacks zip archives, which is what a
        // .wastickers file is.
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archive.path, temporary.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw Failure.nothingToAdd }
        let root = temporary.resolvingSymlinksInPath().path + "/"
        let files = (fileManager.enumerator(at: temporary, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .map { url -> String in
                let path = url.resolvingSymlinksInPath().path
                return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : url.lastPathComponent
            }
        let titleFile = files.first { ($0 as NSString).lastPathComponent.lowercased() == "title.txt" }
        let title = titleFile.flatMap { try? String(contentsOf: temporary.appendingPathComponent($0), encoding: .utf8) }
        let target = folder.appendingPathComponent(StickerArchive.folderName(title: title, archive: archive), isDirectory: true)
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        return try StickerArchive.stickers(in: files).compactMap { path in
            let source = temporary.appendingPathComponent(path)
            guard let kind = MemeKind(url: source) else { return nil }
            let url = MemeImport.uniqueURL(name: source.deletingPathExtension().lastPathComponent, kind: kind, in: target)
            try fileManager.copyItem(at: source, to: url)
            return url
        }
    }

    private static func download(_ link: URL, into folder: URL, convert: Bool) async throws -> [URL] {
        // A getstickerpack pack (its page or its "Add to WhatsApp" link):
        // the whole pack. A link to one of its files is just that sticker.
        if MemeKind(url: link) == nil, let slug = StickerPackLink.slug(from: link) {
            return try await downloadPack(slug: slug, title: StickerPackLink.title(from: link), into: folder)
        }
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
        if StickerArchive.isArchive(source), data.starts(with: [0x50, 0x4B]) {
            // A link to a sticker pack file ("PK", a zip): unpack it.
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(source.lastPathComponent)
            try data.write(to: file, options: .atomic)
            defer { try? FileManager.default.removeItem(at: file) }
            let added = try await Task.detached(priority: .userInitiated) { try unpack(file, into: folder) }.value
            if added.isEmpty { throw Failure.nothingToAdd }
            return added
        }
        guard let kind = MemeImport.kind(sniffing: data) else { throw Failure.nothingToAdd }
        let name = giphy?.name ?? MemeImport.suggestedName(for: source)
        return [try await write(data, kind: kind, name: name, into: folder, convert: convert)]
    }
}

extension MemeImporter {
    /// Downloads a getstickerpack pack into a folder named after it.
    fileprivate static func downloadPack(slug: String, title: String?, into folder: URL) async throws -> [URL] {
        let name = StickerPackLink.folderName(slug: slug, title: title)
        let target = folder.appendingPathComponent(name, isDirectory: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (added, existing) = await Task.detached(priority: .userInitiated) {
            await StickerPackFetcher.fetch(slug: slug, into: target, session: session)
        }.value
        if added.isEmpty {
            if existing > 0 { throw Failure.packAlreadyAdded(name) }
            throw Failure.download(String(localized: "the pack has no stickers F4 can download"))
        }
        return added
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
