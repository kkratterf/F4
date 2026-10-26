import AppKit
import SwiftUI

/// The panel's hosting view, which also takes drops: files, stickers dragged
/// out of an app, images and links. The pasteboard goes to `onDrop`
/// (`MemeImporter` reads it); the view only says whether to accept.
final class DropHostingView<Content: View>: NSHostingView<Content> {
    var onDrop: ((NSPasteboard) -> Void)?
    /// Called with true when a drag enters the panel and false when it leaves or ends.
    var onDragChange: ((Bool) -> Void)?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes(MemeImporter.dropTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard accepts(sender) else { return [] }
        onDragChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        accepts(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragChange?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDragChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard)
        return true
    }

    private func accepts(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let promises = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        return MemeImporter.canImport(pasteboard) || pasteboard.types?.contains(where: { promises.contains($0) }) == true
    }
}
