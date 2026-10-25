import AppKit
import Combine
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
    private let settings = AppSettings.shared
    private lazy var library = MemeLibrary(folder: settings.memeFolder)
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon and no menu bar of our own (also set via LSUIElement in the bundle).
        NSApp.setActivationPolicy(.accessory)
        library.reload()
        settings.$memeFolder
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] url in self?.library.setFolder(url) }
            .store(in: &cancellables)
        let panel = PanelController(library: library)
        self.panel = panel
        registerToggleShortcut()
        statusItem = StatusItemController(
            shortcut: settings.toggleShortcut.displayString,
            onOpen: { [weak self] in self?.panel?.show() },
            onOpenFolder: { [weak self] in
                guard let self else { return }
                NSWorkspace.shared.open(self.library.folder)
            },
            onSettings: { [weak self] in self?.settingsWindow.show() }
        )
        // Opening the app from Finder or Spotlight shows the panel right away.
        panel.show()
    }

    /// The shortcut (⌘⇧M by default) shows or hides the panel from anywhere.
    /// Carbon hot keys need no Accessibility or Input Monitoring permission and
    /// swallow the key press. Re-registered whenever the user records a new one.
    private func registerToggleShortcut() {
        apply(settings.toggleShortcut)
        settings.$toggleShortcut
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] combo in self?.apply(combo) }
            .store(in: &cancellables)
    }

    private func apply(_ combo: HotKeyCombo) {
        let registered = HotKeyCenter.shared.register(id: Self.toggleShortcutID, combo: combo) { [weak self] in
            self?.panel?.toggle()
        }
        statusItem?.update(shortcut: combo.displayString)
        if registered {
            settingsWindow.setShortcutError(nil)
        } else {
            // Usually another app owns the combination.
            NSLog("F4: could not register %@, another app may be using it", combo.displayString)
            settingsWindow.setShortcutError("\(combo.displayString) is taken by another app. Record a different shortcut.")
        }
    }

    private static let toggleShortcutID = "togglePanel"

    /// Opening the app again while it runs shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.show()
        return false
    }
}
