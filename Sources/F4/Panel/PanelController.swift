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
    static let size = NSSize(width: 720, height: 500)

    private let panel: FloatingPanel
    private let library: MemeLibrary
    private let model: DeckModel
    private var keyMonitor: Any?
    private let guides = SnapGuideWindow()
    /// True once a drag has actually moved the panel.
    private var didDrag = false

    private let usage: UsageStore

    init(library: MemeLibrary, usage: UsageStore) {
        self.library = library
        self.usage = usage
        model = DeckModel(library: library, usage: usage)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        super.init()
        let deck = DeckView(
            model: model,
            library: library,
            onPick: { [weak self] meme in self?.pick(meme) },
            onDrag: { [weak self] drag in self?.drag(drag) }
        )
        let hosting = NSHostingView(rootView: deck)
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
    }

    /// Copies the meme and gets out of the way, so the user can paste right away.
    private func pick(_ meme: Meme) {
        guard MemeClipboard.copy(meme) else {
            hide()
            return
        }
        usage.recordCopy(meme)
        hide()
        if AppSettings.shared.pasteAfterCopy {
            AutoPaster.pasteSoon()
        }
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
        // The shadow follows the content's rounded shape once it is drawn.
        DispatchQueue.main.async { [panel] in panel.invalidateShadow() }
    }

    func hide() {
        stopArrowKeys()
        guides.hide()
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
            guard let self, event.window === self.panel else { return event }
            self.model.feedKonami(Self.konamiKey(for: event))
            guard let direction = Self.direction(for: event) else { return event }
            return self.model.move(direction) ? nil : event
        }
    }

    private func stopArrowKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private static func konamiKey(for event: NSEvent) -> KonamiCode.Key {
        switch Int(event.keyCode) {
        case kVK_UpArrow: return .up
        case kVK_DownArrow: return .down
        case kVK_LeftArrow: return .left
        case kVK_RightArrow: return .right
        case kVK_ANSI_B: return .b
        case kVK_ANSI_A: return .a
        default: return .other
        }
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

    // MARK: Position

    /// Where the user last left the panel, as `PanelPlacement.relativeCentre`;
    /// nil until they move it, or after they snap it back to the default spot.
    private static let positionKey = "panelPosition"

    private var savedCentre: CGPoint? {
        get {
            guard let values = UserDefaults.standard.array(forKey: Self.positionKey) as? [Double],
                  values.count == 2 else { return nil }
            return CGPoint(x: values[0], y: values[1])
        }
        set {
            if let newValue {
                UserDefaults.standard.set([Double(newValue.x), Double(newValue.y)], forKey: Self.positionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.positionKey)
            }
        }
    }

    /// Opens on the screen with the mouse, where the user last dragged the
    /// panel (at the same place relative to that screen), or where Spotlight sits.
    private func position(on screen: NSScreen?) {
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = savedCentre.map { PanelPlacement.origin(relativeCentre: $0, size: size, in: visible) }
            ?? PanelPlacement.defaultOrigin(size: size, in: visible)
        panel.setFrameOrigin(origin)
    }

    /// Moves the panel with the mouse, snapping to the screen's centre lines
    /// and the default height, and remembers where it was left.
    private func drag(_ drag: PanelDrag) {
        switch drag {
        case .began:
            didDrag = false
        case .moved(let proposed):
            guard let screen = screenWithMouse() ?? panel.screen else { return }
            let snap = PanelPlacement.snap(proposed, size: panel.frame.size, in: screen.visibleFrame)
            panel.setFrameOrigin(snap.origin)
            guides.show(snap.guides, on: screen, below: panel)
            didDrag = true
        case .ended:
            guides.hide()
            guard didDrag, let screen = panel.screen else { return }
            let visible = screen.visibleFrame
            let snap = PanelPlacement.snap(panel.frame.origin, size: panel.frame.size, in: visible)
            savedCentre = snap.isDefault ? nil : PanelPlacement.relativeCentre(of: panel.frame, in: visible)
        }
    }

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
