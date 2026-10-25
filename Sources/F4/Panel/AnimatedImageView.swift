import AppKit
import SwiftUI

/// Plays an animated GIF with `NSImageView`, which drives the frames itself.
///
/// Only the hovered or selected cell uses it, so at most a couple of GIFs
/// animate at once; every other cell stays a static thumbnail.
struct AnimatedImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.animates = true
        view.isEditable = false
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = image
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image !== image { nsView.image = image }
    }
}
