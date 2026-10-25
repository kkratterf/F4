import AppKit

/// The borderless floating window ReactionDeck lives in, like Spotlight or Raycast.
///
/// A non-activating panel: it takes keyboard focus without bringing ReactionDeck
/// to the front, so the app the user is in stays active and gets focus back
/// when the panel hides. It joins every Space and floats over full-screen apps.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // A titled panel gets the rounded, shadowed window frame for free; the
        // title bar itself is made invisible.
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    // Borderless-looking panels refuse key status by default; the search field needs it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
