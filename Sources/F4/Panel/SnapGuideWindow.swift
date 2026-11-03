import AppKit
import F4Core

/// The thin lines that show where the panel snapped while it is dragged,
/// like Raycast's. A clear window over the whole screen, just below the
/// panel, that never takes a click.
@MainActor
final class SnapGuideWindow: NSPanel {
    private let guideView = GuideView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        contentView = guideView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Draws `guides` across `screen`, under `panel`. No guides hides the window.
    func show(_ guides: [PanelPlacement.Guide], on screen: NSScreen, below panel: NSWindow) {
        guard !guides.isEmpty else {
            hide()
            return
        }
        if frame != screen.frame { setFrame(screen.frame, display: false) }
        guideView.guides = guides
        guideView.visible = screen.visibleFrame
        if !isVisible { order(.below, relativeTo: panel.windowNumber) }
    }

    func hide() {
        guard isVisible else { return }
        orderOut(nil)
    }

    private final class GuideView: NSView {
        var guides: [PanelPlacement.Guide] = [] { didSet { needsDisplay = true } }
        /// The screen's visible frame, in screen coordinates: the lines stop at the menu bar and the Dock.
        var visible: CGRect = .zero

        override func draw(_ dirtyRect: NSRect) {
            guard let window else { return }
            // Screen coordinates to this view's, which covers the whole screen.
            let bounds = visible.offsetBy(dx: -window.frame.minX, dy: -window.frame.minY)
            let path = NSBezierPath()
            for guide in guides {
                switch guide {
                case .vertical(let x):
                    let x = x - window.frame.minX
                    path.move(to: NSPoint(x: x, y: bounds.minY))
                    path.line(to: NSPoint(x: x, y: bounds.maxY))
                case .horizontal(let y):
                    let y = y - window.frame.minY
                    path.move(to: NSPoint(x: bounds.minX, y: y))
                    path.line(to: NSPoint(x: bounds.maxX, y: y))
                }
            }
            path.lineWidth = 1
            path.setLineDash([6, 4], count: 2, phase: 0)
            NSColor.controlAccentColor.withAlphaComponent(0.85).setStroke()
            path.stroke()
        }
    }
}
