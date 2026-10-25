import AppKit

/// The menu bar icon: with no Dock icon, it is how the user finds F4 again.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onOpen: () -> Void
    private let onOpenFolder: () -> Void
    private let onSettings: () -> Void
    private var shortcut: String

    /// - Parameter shortcut: shown next to "Open F4", e.g. "⌘⇧M".
    init(
        shortcut: String,
        onOpen: @escaping () -> Void,
        onOpenFolder: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.onOpen = onOpen
        self.onOpenFolder = onOpenFolder
        self.onSettings = onSettings
        self.shortcut = shortcut
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "F4")
            button.image?.isTemplate = true
        }
        update(shortcut: shortcut)
    }

    /// Shows a new shortcut in the tooltip and the menu.
    func update(shortcut: String) {
        self.shortcut = shortcut
        statusItem.button?.toolTip = "F4 (\(shortcut))"
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
        menu.items = [open, shortcutHint, .separator(), folder, settings, .separator(), quit]
        return menu
    }

    @objc private func open(_ sender: Any?) { onOpen() }
    @objc private func openFolder(_ sender: Any?) { onOpenFolder() }
    @objc private func openSettings(_ sender: Any?) { onSettings() }
}
