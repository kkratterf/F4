import AppKit

/// The menu bar icon: with no Dock icon, it is how the user finds F4 again.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onOpen: () -> Void
    private let onOpenFolder: () -> Void
    private let onSettings: () -> Void
    private let onCheckForUpdates: (() -> Void)?
    private var shortcut: String

    /// - Parameters:
    ///   - shortcut: shown next to "Open F4", e.g. "F4".
    ///   - onCheckForUpdates: nil in builds where the updater is unavailable,
    ///     which leaves the menu item out entirely.
    init(
        shortcut: String,
        onOpen: @escaping () -> Void,
        onOpenFolder: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onCheckForUpdates: (() -> Void)? = nil
    ) {
        self.onOpen = onOpen
        self.onOpenFolder = onOpenFolder
        self.onSettings = onSettings
        self.onCheckForUpdates = onCheckForUpdates
        self.shortcut = shortcut
        super.init()
        statusItem.button?.image = Self.keycapImage()
        update(shortcut: shortcut)
    }

    /// The F4 keycap, the app's logo, as a template image: a filled key with
    /// "F4" cut out of it, so it follows the menu bar's colour.
    private static func keycapImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 15), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 0.5), xRadius: 4, yRadius: 4).fill()
            let label = NSAttributedString(string: "F4", attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .heavy),
                .foregroundColor: NSColor.black,
            ])
            let size = label.size()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            label.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
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
        statusItem.menu = makeMenu(shortcut: shortcut)
    }

    private func makeMenu(shortcut: String) -> NSMenu {
        let menu = NSMenu()
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
        menu.items = [open, shortcutHint, .separator(), folder, settings]
        if onCheckForUpdates != nil {
            let updates = NSMenuItem(
                title: String(localized: "Check for Updates…"),
                action: #selector(checkForUpdates(_:)),
                keyEquivalent: ""
            )
            updates.target = self
            menu.items.append(updates)
        }
        menu.items.append(contentsOf: [.separator(), quit])
        return menu
    }

    @objc private func open(_ sender: Any?) { onOpen() }
    @objc private func openFolder(_ sender: Any?) { onOpenFolder() }
    @objc private func openSettings(_ sender: Any?) { onSettings() }
    @objc private func checkForUpdates(_ sender: Any?) { onCheckForUpdates?() }
}
