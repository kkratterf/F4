import AppKit
import F4Core

/// The menu bar icon and its menu: a plain `NSMenu`, so it looks and behaves
/// like every other menu on the Mac. With no Dock icon, it is how the user
/// finds F4 again, and since F4 has no Settings window it holds the options
/// too, as Maramao's menu does.
///
/// Sections, each between separators: open F4, the recent stickers, the
/// folders and the packs (plus one option for a folder picked in an older
/// version), how to add stickers, updates and quit. The shortcut is always fn F4 and F4 always
/// starts at login, so neither is an option. The menu is rebuilt every time it opens, so the
/// recents and the checkmarks are always current.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// How many recent memes the menu lists.
    static let recentCount = 5
    /// Points for the thumbnails next to recent memes.
    private static let thumbnailSide: CGFloat = 18

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let settings: AppSettings
    private let library: MemeLibrary
    private let organizer: LibraryOrganizer
    private let packs: PackDownloader
    private let onOpen: () -> Void
    private let onHelp: () -> Void
    private let recentMemes: () -> [Meme]
    private let onCopy: (Meme) -> Void
    private var shortcut: String
    /// Set when macOS refused the shortcut, usually because another app owns it.
    private var shortcutError: String?

    /// - Parameters:
    ///   - shortcut: shown in the icon's tooltip, e.g. "fn F4".
    ///   - recentMemes: the memes copied last, most recent first.
    ///   - onCopy: copies a meme picked from the menu.
    init(
        settings: AppSettings,
        library: MemeLibrary,
        organizer: LibraryOrganizer,
        packs: PackDownloader,
        shortcut: String,
        recentMemes: @escaping () -> [Meme],
        onCopy: @escaping (Meme) -> Void,
        onOpen: @escaping () -> Void,
        onHelp: @escaping () -> Void
    ) {
        self.settings = settings
        self.library = library
        self.organizer = organizer
        self.packs = packs
        self.recentMemes = recentMemes
        self.onCopy = onCopy
        self.onOpen = onOpen
        self.onHelp = onHelp
        self.shortcut = shortcut
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.image = Self.keycapImage()
        update(shortcut: shortcut)
    }

    /// "F4" in Inter Display Black, in the logo's 1024 design space (y down,
    /// centred on (512, 458)): the same outlines as site/logo.svg. The third outline is the hole in the 4.
    private static let glyphOutlines: [[(CGFloat, CGFloat)]] = [
        [(311.1, 578), (378.1, 578), (378.1, 491.7), (484.9, 491.7), (484.9, 437.2), (378.1, 437.2), (378.1, 394.7), (491.3, 394.7), (491.3, 338), (311.1, 338)],
        [(506.1, 531.6), (623.4, 531.6), (623.4, 578), (686.2, 578), (686.2, 531.6), (712.9, 531.6), (712.9, 482.3), (686.2, 482.3), (686.2, 338), (603.9, 338), (506.1, 481)],
        [(623.4, 482.3), (566.5, 482.3), (566.5, 482), (623.2, 397.9), (623.4, 397.9)],
    ]

    /// The F4 keycap, the app's logo, as a template image: a filled key with
    /// "F4" cut out of it, so it follows the menu bar's colour.
    private static func keycapImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 15), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 0.5), xRadius: 4, yRadius: 4).fill()
            // 7 pt tall letters, flipped into the image's y-up space.
            let scale: CGFloat = 7 / 240
            let label = NSBezierPath()
            label.windingRule = .evenOdd
            for outline in glyphOutlines {
                for (index, (x, y)) in outline.enumerated() {
                    let point = NSPoint(x: rect.midX + (x - 512) * scale, y: rect.midY - (y - 458) * scale)
                    if index == 0 { label.move(to: point) } else { label.line(to: point) }
                }
                label.close()
            }
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            label.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "F4"
        return image
    }

    /// Shows the shortcut in the tooltip.
    func update(shortcut: String) {
        self.shortcut = shortcut
        statusItem.button?.toolTip = "F4 · basito (\(shortcut))"
    }

    /// Shown under "Open F4" when macOS refused the shortcut; nil clears it.
    func setShortcutError(_ message: String?) {
        shortcutError = message
    }

    /// Opens the menu under the pointer: for `f4://settings`, and for when
    /// the icon is hidden behind the notch or a full menu bar.
    func popUpAtPointer() {
        menuNeedsUpdate(menu)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items = makeItems()
    }

    private func makeItems() -> [NSMenuItem] {
        var items = openItems()
        let recents = recentMemes().prefix(Self.recentCount)
        if !recents.isEmpty {
            items.append(.separator())
            items.append(NSMenuItem.sectionHeader(title: String(localized: "Recent Stickers")))
            items.append(contentsOf: recents.map { recentItem($0) })
        }
        items.append(.separator())
        items.append(foldersItem())
        if !packs.packs.isEmpty {
            items.append(packsItem())
        }
        let options = optionItems()
        if !options.isEmpty {
            items.append(.separator())
            items.append(contentsOf: options)
        }
        items.append(.separator())
        items.append(item(String(localized: "How to Add Stickers…")) { [weak self] in self?.onHelp() })
        let updater = AppUpdater.shared
        if updater.isAvailable {
            items.append(updateItem(updater))
        }
        items.append(item(String(localized: "Quit F4"), key: "q") { NSApp.terminate(nil) })
        return items
    }

    /// "Open F4", and why the F4 key does not open it when another app owns it.
    private func openItems() -> [NSMenuItem] {
        var items = [item(String(localized: "Open F4")) { [weak self] in self?.onOpen() }]
        if let shortcutError {
            let hint = NSMenuItem(title: shortcutError, action: nil, keyEquivalent: "")
            hint.isEnabled = false
            items.append(hint)
        }
        return items
    }

    /// "Options", shown only with a sticker folder other than F4's own
    /// library (from older versions): whether to list the starter pack too.
    private func optionItems() -> [NSMenuItem] {
        // F4's own library holds a copy of the starter pack: nothing to show on top.
        guard !library.isAppLibrary else { return [] }
        let starter = item(String(localized: "Show Starter Pack")) { [weak self] in
            self?.settings.showStarterPack.toggle()
        }
        starter.state = settings.showStarterPack ? .on : .off
        starter.toolTip = String(localized: "The stickers built into F4, listed after yours.")
        return [NSMenuItem.sectionHeader(title: String(localized: "Options")), starter]
    }

    /// "Folders ▸ New Folder…, then each folder ▸ Rename…, Move to Trash":
    /// the folders of the library, managed without Finder. Moving a meme
    /// into one is in the meme's right-click menu in the panel.
    private func foldersItem() -> NSMenuItem {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.addItem(item(String(localized: "New Folder…")) { [weak self] in
            _ = try? self?.organizer.newFolder()
        })
        let folders = library.folders
        if !folders.isEmpty { submenu.addItem(.separator()) }
        for category in folders {
            let actions = NSMenu()
            actions.autoenablesItems = false
            actions.addItem(item(String(localized: "Rename…")) { [weak self] in self?.organizer.renameFolder(category) })
            actions.addItem(item(String(localized: "Move to Trash")) { [weak self] in self?.organizer.trashFolder(category) })
            let entry = NSMenuItem(title: category, action: nil, keyEquivalent: "")
            entry.submenu = actions
            submenu.addItem(entry)
        }
        let parent = NSMenuItem(title: String(localized: "Folders"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    /// "Packs ▸ each pack", a switch: turning a pack on downloads its
    /// stickers into a folder of the library (only then, never on its own);
    /// turning it off moves them to the Trash, after a confirmation.
    private func packsItem() -> NSMenuItem {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for pack in packs.packs {
            let isDownloading = packs.downloading == pack.id
            let title = isDownloading ? String(localized: "Downloading \(pack.name)…") : pack.name
            let isOn = packs.downloaded.contains(pack.id)
            let entry = item(title) { [weak self] in
                guard let self else { return }
                if isOn {
                    if organizer.trashFolders([pack.category], named: pack.name) { packs.forget(pack) }
                } else {
                    download(pack)
                }
            }
            entry.state = isOn ? .on : .off
            entry.isEnabled = packs.downloading == nil
            submenu.addItem(entry)
        }
        let parent = NSMenuItem(title: String(localized: "Packs"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    private func download(_ pack: ContentPack) {
        packs.download(pack) { added, failed in
            let alert = NSAlert()
            alert.messageText = added == 1
                ? String(localized: "Added 1 sticker from \(pack.name)")
                : String(localized: "Added \(String(added)) stickers from \(pack.name)")
            if failed > 0 {
                alert.informativeText = String(localized: "\(String(failed)) could not be downloaded.")
            }
            NSApp.activate(ignoringOtherApps: true)
            alert.window.level = .modalPanel
            alert.runModal()
        }
    }

    /// "Update to Version x…" once Sparkle found one, "Check for Updates…" otherwise.
    private func updateItem(_ updater: AppUpdater) -> NSMenuItem {
        let title: String
        if let version = updater.pendingUpdateVersion {
            title = String(localized: "Update to Version \(version)…")
        } else {
            title = String(localized: "Check for Updates…")
        }
        let entry = item(title) { updater.checkForUpdates() }
        entry.isEnabled = updater.pendingUpdateVersion != nil || updater.canCheckForUpdates
        return entry
    }

    /// A recent meme: its name, and its thumbnail when it is already decoded
    /// (the menu never waits for one). Clicking copies it.
    private func recentItem(_ meme: Meme) -> NSMenuItem {
        let entry = item(meme.name) { [weak self] in self?.onCopy(meme) }
        entry.toolTip = meme.category.map { "\($0)/\(meme.name)" } ?? meme.name
        if let thumbnail = ThumbnailCache.shared.cached(meme, maxPixelSize: MemeCell.thumbnailPixels) {
            entry.image = Self.square(thumbnail)
        }
        return entry
    }

    /// The thumbnail cropped to a small rounded square, like a grid cell.
    private static func square(_ image: CGImage) -> NSImage {
        let side = thumbnailSide
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).addClip()
            let scale = max(side / CGFloat(image.width), side / CGFloat(image.height))
            let size = NSSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            NSImage(cgImage: image, size: size).draw(in: NSRect(
                x: rect.midX - size.width / 2,
                y: rect.midY - size.height / 2,
                width: size.width,
                height: size.height
            ))
            return true
        }
    }

    private func item(_ title: String, key: String = "", action: @escaping () -> Void) -> NSMenuItem {
        ClosureMenuItem(title: title, keyEquivalent: key, action: action)
    }
}

/// A menu item that runs a closure, so the menu needs no selector per command.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run(_:)), keyEquivalent: keyEquivalent)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func run(_ sender: Any?) {
        handler()
    }
}
