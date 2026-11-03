import AppKit
import F4Core

/// The menu bar icon: with no Dock icon, it is how the user finds F4 again.
///
/// Its menu opens the panel, copies one of the last memes again without
/// opening anything, and leads to the folder, the settings and updates.
/// The user can hide it in Settings; opening F4 again then shows Settings.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// How many recent memes the menu lists.
    static let recentCount = 5
    /// Points for the thumbnails next to recent memes.
    private static let thumbnailSide: CGFloat = 18

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onOpen: () -> Void
    private let onOpenFolder: () -> Void
    private let onSettings: () -> Void
    private let onCheckForUpdates: (() -> Void)?
    private let recentMemes: () -> [Meme]
    private let onCopy: (Meme) -> Void
    private var shortcut: String

    /// - Parameters:
    ///   - shortcut: shown next to "Open F4", e.g. "F4".
    ///   - recentMemes: the memes copied last, most recent first.
    ///   - onCopy: copies a meme picked from the menu.
    ///   - onCheckForUpdates: nil in builds where the updater is unavailable,
    ///     which leaves the menu item out entirely.
    init(
        shortcut: String,
        recentMemes: @escaping () -> [Meme],
        onCopy: @escaping (Meme) -> Void,
        onOpen: @escaping () -> Void,
        onOpenFolder: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onCheckForUpdates: (() -> Void)? = nil
    ) {
        self.recentMemes = recentMemes
        self.onCopy = onCopy
        self.onOpen = onOpen
        self.onOpenFolder = onOpenFolder
        self.onSettings = onSettings
        self.onCheckForUpdates = onCheckForUpdates
        self.shortcut = shortcut
        super.init()
        statusItem.button?.image = Self.keycapImage()
        update(shortcut: shortcut)
    }

    /// "F4" in Inter Display Black, in the logo's 1024 design space (y down,
    /// centred on (512, 458)): the same outlines as scripts/make-icon.swift
    /// and site/logo.svg. The third outline is the hole in the 4.
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

    /// Shows or hides the icon (Settings → Show F4 in the menu bar).
    var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    /// Shows a new shortcut in the tooltip and the menu.
    func update(shortcut: String) {
        self.shortcut = shortcut
        statusItem.button?.toolTip = "F4 · basito (\(shortcut))"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: NSMenuDelegate

    /// Rebuilt every time it opens, so the recent memes are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items = makeItems(shortcut: shortcut)
    }

    private func makeItems(shortcut: String) -> [NSMenuItem] {
        let open = NSMenuItem(title: String(localized: "Open F4"), action: #selector(open(_:)), keyEquivalent: "")
        open.target = self
        // The shortcut is global (Carbon), not a menu key equivalent: this line only tells the user.
        let shortcutHint = NSMenuItem(title: String(localized: "Shortcut: \(shortcut)"), action: nil, keyEquivalent: "")
        shortcutHint.isEnabled = false
        let folder = NSMenuItem(title: String(localized: "Open Meme Folder"), action: #selector(openFolder(_:)), keyEquivalent: "")
        folder.target = self
        let settings = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings(_:)), keyEquivalent: ",")
        settings.target = self
        let quit = NSMenuItem(title: String(localized: "Quit F4"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        var items: [NSMenuItem] = [open, shortcutHint, .separator()]
        let recents = recentMemes().prefix(Self.recentCount)
        if !recents.isEmpty {
            items.append(NSMenuItem.sectionHeader(title: String(localized: "Recent Memes")))
            items.append(contentsOf: recents.map { recentItem($0) })
            items.append(.separator())
        }
        items.append(contentsOf: [folder, settings])
        if onCheckForUpdates != nil {
            let updates = NSMenuItem(
                title: String(localized: "Check for Updates…"),
                action: #selector(checkForUpdates(_:)),
                keyEquivalent: ""
            )
            updates.target = self
            items.append(updates)
        }
        items.append(contentsOf: [.separator(), quit])
        return items
    }

    /// A recent meme: its name, and its thumbnail when it is already decoded
    /// (the menu never waits for one). Clicking copies it.
    private func recentItem(_ meme: Meme) -> NSMenuItem {
        let item = NSMenuItem(title: meme.name, action: #selector(copyMeme(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = meme
        item.toolTip = meme.category.map { "\($0)/\(meme.name)" } ?? meme.name
        if let thumbnail = ThumbnailCache.shared.cached(meme, maxPixelSize: MemeCell.thumbnailPixels) {
            item.image = Self.square(thumbnail)
        }
        return item
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

    @objc private func copyMeme(_ sender: NSMenuItem) {
        if let meme = sender.representedObject as? Meme { onCopy(meme) }
    }

    @objc private func open(_ sender: Any?) { onOpen() }
    @objc private func openFolder(_ sender: Any?) { onOpenFolder() }
    @objc private func openSettings(_ sender: Any?) { onSettings() }
    @objc private func checkForUpdates(_ sender: Any?) { onCheckForUpdates?() }
}
