import AppKit
import SwiftUI

/// A regular window for the settings. F4 is an accessory app with no main
/// menu, so it owns this window instead of relying on SwiftUI's `Settings` scene.
///
/// While the window is open F4 turns into a regular app (Dock icon, ⌘Tab).
/// An accessory app's window opens over whatever is in front, even a
/// full-screen app on its own Space; a regular app's window opens on a
/// desktop like any other app's. F4 goes back to the menu bar on close.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settings: AppSettings
    private let state = SettingsWindowState()

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Shown under the shortcut recorder; nil clears it.
    func setShortcutError(_ message: String?) {
        state.shortcutError = message
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsRoot(settings: settings, state: state)))
            window.title = String(localized: "F4 Settings")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenNone]
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        // An app must activate itself, or the window opens behind the front app.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu bar app, without a Dock icon; the app that was in
        // front before Settings gets the focus back.
        NSApp.setActivationPolicy(.accessory)
    }
}

/// State the app delegate pushes into the settings window.
@MainActor
final class SettingsWindowState: ObservableObject {
    @Published var shortcutError: String?
}

private struct SettingsRoot: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var state: SettingsWindowState

    var body: some View {
        SettingsView(settings: settings, shortcutError: state.shortcutError)
    }
}
