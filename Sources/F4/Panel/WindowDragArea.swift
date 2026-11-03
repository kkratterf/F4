import AppKit
import SwiftUI

/// A step of the user dragging the panel by its search bar or footer.
enum PanelDrag {
    case began
    /// Where the panel's origin would be if it followed the mouse exactly.
    case moved(to: NSPoint)
    case ended
}

/// The parts of the panel that move it, behind the search bar and the footer.
///
/// The panel moves itself instead of letting the window server drag it, so
/// `PanelController` can snap it to guides while it moves. Controls on top
/// (the search field, the buttons) still get their own clicks.
struct WindowDragArea: NSViewRepresentable {
    let onDrag: (PanelDrag) -> Void

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ nsView: DragView, context: Context) {
        nsView.onDrag = onDrag
    }

    final class DragView: NSView {
        var onDrag: ((PanelDrag) -> Void)?

        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let start = NSEvent.mouseLocation
            let startOrigin = window.frame.origin
            onDrag?(.began)
            // The usual AppKit drag loop: take the mouse events until the button goes up.
            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]),
                  next.type == .leftMouseDragged {
                let mouse = NSEvent.mouseLocation
                onDrag?(.moved(to: NSPoint(
                    x: startOrigin.x + mouse.x - start.x,
                    y: startOrigin.y + mouse.y - start.y
                )))
            }
            onDrag?(.ended)
        }
    }
}
