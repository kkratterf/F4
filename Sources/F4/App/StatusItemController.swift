import AppKit
import Carbon.HIToolbox
import F4Core

/// The menu bar icon and its menu: a plain `NSMenu`, so it looks and behaves
/// like every other menu on the Mac. With no Dock icon, it is how the user
/// finds F4 again, and since F4 has no Settings window it holds the options
/// too, as Maramao's menu does.
///
/// Sections, each between separators: open F4, the recent memes, the meme
/// folder and its folders, the options (each a checkmark, the shortcut in a submenu),
/// updates and About, quit. The menu is rebuilt every time it opens, so the
/// recents and the checkmarks are always current.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// How many recent memes the menu lists.
    static let recentCount = 5
    /// Points for the thumbnails next to recent memes.
    private static let thumbnailSide: CGFloat = 18

    /// Shortcuts offered in the Shortcut submenu, F4 first (the default).
    /// The user's current one is added on top when it is not one of these.
    static let shortcutPresets: [HotKeyCombo] = [
        .toggleDefault,
        HotKeyCombo(keyCode: kVK_Space, modifiers: UInt32(optionKey)),
        HotKeyCombo(keyCode: kVK_Space, modifiers: UInt32(controlKey | optionKey)),
        HotKeyCombo(keyCode: kVK_ANSI_M, modifiers: UInt32(cmdKey | shiftKey)),
        HotKeyCombo(keyCode: kVK_F5, modifiers: 0),
    ]

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let settings: AppSettings
    private let library: MemeLibrary
    private let organizer: LibraryOrganizer
    private let packs: PackDownloader
    private let loginItem = LoginItem()
    private let onOpen: () -> Void
    private let onOpenFolder: () -> Void
    private let onChooseFolder: () -> Void
    private let recentMemes: () -> [Meme]
    private let onCopy: (Meme) -> Void
    private var shortcut: String
    /// Set when macOS refused the shortcut, usually because another app owns it.
    private var shortcutError: String?

    /// - Parameters:
    ///   - shortcut: shown under "Open F4", e.g. "fn F4".
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
        onOpenFolder: @escaping () -> Void,
        onChooseFolder: @escaping () -> Void
    ) {
        self.settings = settings
        self.library = library
        self.organizer = organizer
        self.packs = packs
        self.recentMemes = recentMemes
        self.onCopy = onCopy
        self.onOpen = onOpen
        self.onOpenFolder = onOpenFolder
        self.onChooseFolder = onChooseFolder
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

    /// Shows a new shortcut in the tooltip and the menu.
    func update(shortcut: String) {
        self.shortcut = shortcut
        statusItem.button?.toolTip = "F4 · basito (\(shortcut))"
    }

    /// Shown in place of the shortcut line; nil clears it.
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
        // The user may have changed these in System Settings meanwhile.
        loginItem.refresh()
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
        items.append(item(String(localized: "Open Sticker Folder")) { [weak self] in self?.onOpenFolder() })
        items.append(foldersItem())
        if !packs.packs.isEmpty {
            items.append(packsItem())
        }
        items.append(item(String(localized: "Choose Sticker Folder…")) { [weak self] in self?.onChooseFolder() })
        items.append(.separator())
        items.append(contentsOf: optionItems())
        items.append(.separator())
        let updater = AppUpdater.shared
        if updater.isAvailable {
            items.append(updateItem(updater))
        }
        items.append(item(String(localized: "About F4")) { Self.showAbout() })
        items.append(.separator())
        items.append(item(String(localized: "Quit F4"), key: "q") { NSApp.terminate(nil) })
        return items
    }

    /// "Open F4", then a line with the shortcut, or why it does not work.
    private func openItems() -> [NSMenuItem] {
        let open = item(String(localized: "Open F4")) { [weak self] in self?.onOpen() }
        // The shortcut is global (Carbon), not a menu key equivalent: this line only tells the user.
        let hint = NSMenuItem(
            title: shortcutError ?? String(localized: "Shortcut: \(shortcut)"),
            action: nil,
            keyEquivalent: ""
        )
        hint.isEnabled = false
        return [open, hint]
    }

    /// "Options": the settings that used to live in a window, each a checkmark.
    private func optionItems() -> [NSMenuItem] {
        var items = [NSMenuItem.sectionHeader(title: String(localized: "Options"))]

        let paste = item(String(localized: "Paste After Copying")) { [weak self] in
            guard let self else { return }
            self.settings.pasteAfterCopy.toggle()
            if self.settings.pasteAfterCopy { AutoPaster.requestTrust() }
        }
        paste.state = settings.pasteAfterCopy ? .on : .off
        paste.toolTip = String(localized: "Presses ⌘V in the front app after copying. Needs Accessibility access; without it F4 only copies.")
        items.append(paste)
        var needsAccessibility = settings.pasteAfterCopy && !AutoPaster.isTrusted

        // Only on a Mac whose F4 key is Spotlight or Launchpad, with F4 as the shortcut.
        if settings.toggleShortcut.isF4Alone && !HotKeyCombo.functionKeysAreStandard {
            let withoutFn = item(String(localized: "F4 Key Without fn")) { [weak self] in
                guard let self else { return }
                self.settings.pressF4WithoutFn.toggle()
                if self.settings.pressF4WithoutFn { AutoPaster.requestTrust() }
            }
            withoutFn.state = settings.pressF4WithoutFn ? .on : .off
            withoutFn.toolTip = String(localized: "The F4 key alone opens F4 instead of Spotlight or Launchpad. Needs Accessibility access; fn F4 always works.")
            items.append(withoutFn)
            if settings.pressF4WithoutFn && !MediaF4KeyTap.shared.isRunning { needsAccessibility = true }
        }
        if needsAccessibility {
            // An option is on but macOS has not let F4 act on keys yet.
            items.append(accessibilityItem())
        }

        // F4's own library holds a copy of the starter pack: nothing to show on top.
        if !library.isAppLibrary {
            let starter = item(String(localized: "Show Starter Pack")) { [weak self] in
                self?.settings.showStarterPack.toggle()
            }
            starter.state = settings.showStarterPack ? .on : .off
            starter.toolTip = String(localized: "The stickers built into F4, listed after yours.")
            items.append(starter)
        }

        let login = item(String(localized: "Open at Login")) { [weak self] in
            guard let self else { return }
            self.loginItem.setEnabled(!self.loginItem.isEnabled)
        }
        login.state = loginItem.isEnabled ? .on : .off
        login.toolTip = loginItem.message
        items.append(login)

        items.append(shortcutItem())
        return items
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

    /// "Allow Accessibility…": opens System Settings when an option needs it.
    private func accessibilityItem() -> NSMenuItem {
        let entry = item(String(localized: "Allow Accessibility…")) { AutoPaster.openAccessibilitySettings() }
        entry.indentationLevel = 1
        return entry
    }

    /// "Shortcut ▸ fn F4, ⌥Space, …": the global shortcut that opens the panel.
    private func shortcutItem() -> NSMenuItem {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let current = settings.toggleShortcut
        var combos = Self.shortcutPresets
        if !combos.contains(current) { combos.insert(current, at: 0) }
        for combo in combos {
            let entry = item(combo.displayString) { [weak self] in self?.settings.toggleShortcut = combo }
            entry.state = combo == current ? .on : .off
            submenu.addItem(entry)
        }
        let parent = NSMenuItem(title: String(localized: "Shortcut"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
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

    /// The standard About panel, with the starter pack's credit (CC BY 4.0
    /// asks for it) and F4's promise about the network.
    private static func showAbout() {
        let credits = String(localized: "The starter pack uses Google's Noto Animated Emoji (CC BY 4.0). F4 goes online only for updates, links you paste or drop, and packs you turn on.")
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .credits: NSAttributedString(
                string: credits,
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            ),
        ]
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options)
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
