import Foundation

/// Where the panel sits on a screen, and how it snaps while the user drags it.
///
/// Frames are in AppKit screen coordinates (origin at the bottom left, y up).
/// `visible` is the screen's visible frame: the screen minus the menu bar
/// and the Dock.
public enum PanelPlacement {
    /// How close, in points, the panel has to come to a guide to snap to it.
    public static let snapDistance: CGFloat = 12

    /// Where the panel opens until the user moves it: centred horizontally and
    /// a little above the middle, where Spotlight sits.
    public static func defaultOrigin(size: CGSize, in visible: CGRect) -> CGPoint {
        CGPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + (visible.height - size.height) * 0.6
        )
    }

    /// The centre of `frame` as fractions of `visible` (0 at the left and
    /// bottom, 1 at the right and top). Stored instead of points, so the
    /// position carries over to another screen or resolution.
    public static func relativeCentre(of frame: CGRect, in visible: CGRect) -> CGPoint {
        guard visible.width > 0, visible.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(
            x: (frame.midX - visible.minX) / visible.width,
            y: (frame.midY - visible.minY) / visible.height
        )
    }

    /// The origin of a panel of `size` whose centre is at `centre` (fractions,
    /// as from `relativeCentre`), kept inside `visible`.
    public static func origin(relativeCentre centre: CGPoint, size: CGSize, in visible: CGRect) -> CGPoint {
        let origin = CGPoint(
            x: visible.minX + centre.x * visible.width - size.width / 2,
            y: visible.minY + centre.y * visible.height - size.height / 2
        )
        return clamp(origin, size: size, in: visible)
    }

    /// Moves `origin` the least needed to keep the whole panel inside
    /// `visible`. A panel larger than the screen keeps its top left corner on it.
    public static func clamp(_ origin: CGPoint, size: CGSize, in visible: CGRect) -> CGPoint {
        CGPoint(
            x: max(visible.minX, min(origin.x, visible.maxX - size.width)),
            y: min(visible.maxY - size.height, max(origin.y, visible.minY))
        )
    }

    /// A line the panel snapped to, in screen coordinates.
    public enum Guide: Equatable, Sendable {
        /// A vertical line at `x`: the panel is centred horizontally on the screen.
        case vertical(x: CGFloat)
        /// A horizontal line at `y`, through the centre of the panel: the
        /// screen's middle, or the height the panel opens at by default.
        case horizontal(y: CGFloat)
    }

    /// Where a dragged panel goes, and the guides to draw.
    public struct Snap: Equatable, Sendable {
        public var origin: CGPoint
        public var guides: [Guide]
        /// True when the panel is back exactly where it opens by default.
        public var isDefault: Bool
    }

    /// Snaps a panel dragged to `origin`: its centre to the screen's
    /// vertical centre line, and to the screen's middle or the default
    /// height, whichever is nearer, when it comes within `distance`. The
    /// result stays inside `visible`.
    public static func snap(
        _ origin: CGPoint,
        size: CGSize,
        in visible: CGRect,
        distance: CGFloat = snapDistance
    ) -> Snap {
        var origin = clamp(origin, size: size, in: visible)
        var guides: [Guide] = []
        var centredX = false
        var atDefaultHeight = false

        if abs(origin.x + size.width / 2 - visible.midX) <= distance {
            origin.x = visible.midX - size.width / 2
            guides.append(.vertical(x: visible.midX))
            centredX = true
        }

        let centreY = origin.y + size.height / 2
        let defaultCentreY = defaultOrigin(size: size, in: visible).y + size.height / 2
        let nearest = [defaultCentreY, visible.midY]
            .map { (y: $0, gap: abs(centreY - $0)) }
            .min { $0.gap < $1.gap }
        if let nearest, nearest.gap <= distance {
            origin.y = nearest.y - size.height / 2
            guides.append(.horizontal(y: nearest.y))
            atDefaultHeight = nearest.y == defaultCentreY
        }

        return Snap(origin: origin, guides: guides, isDefault: centredX && atDefaultHeight)
    }
}
