import AppKit
import Carbon.HIToolbox
import F4Core
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
    private let model: DeckModel
    private var keyMonitor: Any?

    init(library: MemeLibrary) {
        self.library = library
        model = DeckModel(library: library)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        super.init()
        let deck = DeckView(model: model, library: library, onPick: { [weak self] meme in self?.pick(meme) })
        let hosting = NSHostingView(rootView: deck)
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
    }

    /// Copies the meme and gets out of the way, so the user can paste right away.
    private func pick(_ meme: Meme) {
        MemeClipboard.copy(meme)
        hide()
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.prepareForShow()
        position(on: screenWithMouse())
        startArrowKeys()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        stopArrowKeys()
        panel.orderOut(nil)
    }

    // MARK: Arrow keys

    /// Arrow keys move the selection in the grid while the search field keeps
    /// the focus, so the user can type and navigate without switching. A local
    /// monitor sees the key before the field editor does; it only exists
    /// while the panel is open and only takes events aimed at the panel.
    private func startArrowKeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel,
                  let direction = Self.direction(for: event) else { return event }
            return self.model.move(direction) ? nil : event
        }
    }

    private func stopArrowKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private static func direction(for event: NSEvent) -> GridDirection? {
        // Leave ⌘/⌥-arrows to the text field (jump to start/end, word by word).
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return nil }
        switch Int(event.keyCode) {
        case kVK_LeftArrow: return .left
        case kVK_RightArrow: return .right
        case kVK_UpArrow: return .up
        case kVK_DownArrow: return .down
        default: return nil
        }
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
