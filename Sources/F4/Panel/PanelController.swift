import AppKit
import SwiftUI

/// Owns the floating panel and shows or hides it.
///
/// The panel and its SwiftUI content are created once at launch and only
/// ordered in and out afterwards, so showing it never waits for a view to load.
///
/// It hides on Esc and as soon as the panel loses key status, which is what
/// happens when the user clicks outside it or switches app. The panel never
/// activates F4, so the app the user was in keeps the focus.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 720, height: 460)

    private let panel: FloatingPanel
    private let library: MemeLibrary

    init(library: MemeLibrary) {
        self.library = library
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        super.init()
        let hosting = NSHostingView(rootView: DeckView(library: library))
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        position(on: screenWithMouse())
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    /// Centred horizontally and a little above the middle, where Spotlight sits.
    private func position(on screen: NSScreen?) {
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + (visible.height - size.height) * 0.6
        )
        panel.setFrameOrigin(origin)
    }

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
