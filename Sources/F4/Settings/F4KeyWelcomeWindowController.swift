import AppKit
import SwiftUI

/// The window shown on the first launch of a Mac whose F4 key is Spotlight or
/// Launchpad: it offers to catch the key, so F4 alone opens the panel, and
/// otherwise explains fn F4. Shown once; the same choice stays in the menu bar menu.
@MainActor
final class F4KeyWelcomeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settings: AppSettings
    private let onFinish: () -> Void

    /// `onFinish` runs when the window closes, however the user closes it.
    init(settings: AppSettings, onFinish: @escaping () -> Void) {
        self.settings = settings
        self.onFinish = onFinish
    }

    func show() {
        if window == nil {
            let view = F4KeyWelcomeView(settings: settings) { [weak self] in self?.window?.close() }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "Welcome to F4")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        settings.didOfferF4WithoutFn = true
        // An accessory app must activate itself, or the window opens behind the front app.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onFinish()
    }
}

private struct F4KeyWelcomeView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var tap = MediaF4KeyTap.shared
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Open F4 with the F4 key")
                .font(.title2.bold())
            if !settings.pressF4WithoutFn {
                Text("On this Mac the F4 key opens Spotlight or Launchpad, so for now F4 opens with fn F4.")
                Text("F4 can catch the F4 key before macOS does, so the key alone opens your memes. It needs Accessibility access for that: F4 only acts on the F4 key and lets every other key through.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Use the F4 key alone") {
                        settings.pressF4WithoutFn = true
                        AutoPaster.requestTrust()
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("Keep fn F4", action: close)
                }
                Button("Or use F1, F2, etc. as standard function keys for every app") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            } else if tap.isRunning {
                Text("All set: press F4 to open your memes. fn F4 works too.")
                Button("Start", action: close)
                    .keyboardShortcut(.defaultAction)
            } else {
                Text("Turn on F4 in System Settings › Privacy & Security › Accessibility. This window updates as soon as you do.")
                Text("Until then, or if you prefer not to, fn F4 opens F4. You can change this later in F4's menu (F4 Key Without fn).")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Open Settings") { AutoPaster.openAccessibilitySettings() }
                        .keyboardShortcut(.defaultAction)
                    Button("Later", action: close)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(width: 440)
    }
}
