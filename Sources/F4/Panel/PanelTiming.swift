import Foundation
import os

/// How long the panel takes to open, in the unified log (subsystem
/// `com.kkratterf.f4`, category `panel`), so CI can check that it opens
/// instantly with a big library (`log show`). It stays on the Mac.
@MainActor
enum PanelTiming {
    private static let log = Logger(subsystem: "com.kkratterf.f4", category: "panel")
    private static var openedAt: ContinuousClock.Instant?
    private static var waitingForThumbnail = false

    /// The shortcut or a URL asked for the panel.
    static func opening() {
        openedAt = .now
        waitingForThumbnail = true
    }

    /// The panel is on screen, laid out and drawn.
    static func shown(stickers: Int) {
        guard let openedAt else { return }
        let ms = milliseconds(since: openedAt)
        log.notice("Panel shown in \(ms, format: .fixed(precision: 1), privacy: .public) ms with \(stickers, privacy: .public) stickers")
    }

    /// A cell drew its thumbnail: the first one soon after an open is
    /// logged. Cells kept from the last open draw theirs at once, without it.
    static func thumbnailShown() {
        guard waitingForThumbnail, let openedAt else { return }
        waitingForThumbnail = false
        let ms = milliseconds(since: openedAt)
        guard ms < 2_000 else { return }
        log.notice("First thumbnail in \(ms, format: .fixed(precision: 1), privacy: .public) ms")
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = (ContinuousClock.now - start).components
        return Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
    }
}
