import AppKit
import SwiftUI

/// "Copied to Clipboard": a small dark pill at the bottom of the screen,
/// shown after a sticker is copied, like Raycast's HUD. It never takes
/// focus or clicks, so the user can paste with ⌘V straight away, and it
/// fades out on its own.
@MainActor
final class CopiedToast {
    static let shared = CopiedToast()

    /// How long the toast stays before it fades.
    private static let visibleFor: TimeInterval = 1.3
    /// Points between the toast and the bottom of the visible screen.
    private static let bottomMargin: CGFloat = 80

    private var window: NSPanel?
    private var hideWork: DispatchWorkItem?

    private init() {}

    /// Shows the toast on the screen with the pointer, or restarts it.
    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = window.contentView?.fittingSize ?? window.frame.size
            window.setFrame(NSRect(
                x: visible.midX - size.width / 2,
                y: visible.minY + Self.bottomMargin,
                width: size.width,
                height: size.height
            ), display: false)
        }
        hideWork?.cancel()
        window.alphaValue = 1
        window.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleFor, execute: work)
    }

    private func fadeOut() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                // A new copy may have shown the toast again meanwhile.
                guard let self, let window = self.window, window.alphaValue == 0 else { return }
                window.orderOut(nil)
            }
        })
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        let hosting = NSHostingView(rootView: ToastView())
        hosting.frame.size = hosting.fittingSize
        panel.setContentSize(hosting.fittingSize)
        panel.contentView = hosting
        return panel
    }
}

private struct ToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Copied to Clipboard")
                .foregroundStyle(.white)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.black.opacity(0.82)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}
