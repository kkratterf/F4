import AppKit
import SwiftUI

@main
struct F4App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app has no regular windows: its UI is the floating panel owned
        // by AppDelegate. SwiftUI needs at least one scene, and an empty
        // Settings scene opens nothing on its own.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PanelController?
    private var statusItem: StatusItemController?
    private let library = MemeLibrary()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon and no menu bar of our own (also set via LSUIElement in the bundle).
        NSApp.setActivationPolicy(.accessory)
        library.reload()
        let panel = PanelController(library: library)
        self.panel = panel
        registerToggleShortcut()
        statusItem = StatusItemController(
            shortcut: HotKeyCombo.toggleDefault.displayString,
            onOpen: { [weak self] in self?.panel?.show() },
            onOpenFolder: { [weak self] in
                guard let self else { return }
                NSWorkspace.shared.open(self.library.folder)
            }
        )
        // Opening the app from Finder or Spotlight shows the panel right away.
        panel.show()
    }

    /// ⌘⇧M anywhere shows or hides the panel. Carbon hot keys need no
    /// Accessibility or Input Monitoring permission and swallow the key press.
    private func registerToggleShortcut() {
        let combo = HotKeyCombo.toggleDefault
        let registered = HotKeyCenter.shared.register(id: Self.toggleShortcutID, combo: combo) { [weak self] in
            self?.panel?.toggle()
        }
        if !registered {
            // Another app owns the combination. A shortcut recorder in the
            // settings will let the user pick another one.
            NSLog("F4: could not register %@, another app may be using it", combo.displayString)
        }
    }

    private static let toggleShortcutID = "togglePanel"

    /// Opening the app again while it runs shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.show()
        return false
    }
}
