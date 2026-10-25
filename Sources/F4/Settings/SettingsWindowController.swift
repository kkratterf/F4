import AppKit
import SwiftUI

/// A regular window for the settings. F4 is an accessory app with no main
/// menu, so it owns this window instead of relying on SwiftUI's `Settings` scene.
@MainActor
final class SettingsWindowController {
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
            window.title = "F4 Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // An accessory app must activate itself, or the window opens behind the front app.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
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
