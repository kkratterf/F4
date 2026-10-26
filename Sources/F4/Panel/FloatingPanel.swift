import AppKit

/// The borderless floating window F4 lives in, like Spotlight or Raycast.
///
/// A non-activating panel: it takes keyboard focus without bringing F4
/// to the front, so the app the user is in stays active and gets focus back
/// when the panel hides. It joins every Space and floats over full-screen apps.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        // The panel moves itself when dragged by its search bar or footer
        // (`WindowDragArea`), so it can snap to guides on the way.
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        // Borderless and clear: the rounded shape is drawn by the content
        // (`DeckView`), and the window server shapes the shadow after it.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    /// Corner radius of the panel, continuous like Raycast's and the Dock's.
    static let cornerRadius: CGFloat = 16

    /// Called on Esc. The panel does not close itself: its controller decides.
    var onCancel: (() -> Void)?

    /// Esc anywhere in the panel, including inside the search field, whose
    /// field editor forwards `cancelOperation(_:)` up the responder chain.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    // Borderless panels refuse key status by default; the search field needs it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
