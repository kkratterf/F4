import AppKit
import SwiftUI

/// "Add your stickers": how to fill F4, in three keys. Shown once, on the
/// first launch, and again from "How to Add Stickers…" in the menu bar menu
/// and the ⓘ button in the panel.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let onOpenF4: () -> Void

    /// `onOpenF4` shows the panel: the window's main button.
    init(onOpenF4: @escaping () -> Void) {
        self.onOpenF4 = onOpenF4
    }

    func show() {
        if window == nil {
            let view = WelcomeView { [weak self] in
                self?.window?.close()
                self?.onOpenF4()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "Welcome to F4")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        // An accessory app must activate itself, or the window opens behind the front app.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct WelcomeView: View {
    let openF4: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add your stickers")
                    .font(.title.bold())
                Text("Any sticker or image you can copy can live in F4. It takes three keys.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 16) {
                Step(keys: ["⌘", "C"], title: "Copy a sticker or an image",
                     detail: "In WhatsApp, right-click a sticker and choose Copy. Photos, pictures from a website and files in Finder work too.")
                Step(keys: ["fn", "F4"], title: "Open F4",
                     detail: "From any app.")
                Step(keys: ["⌘", "V"], title: "Paste it",
                     detail: "F4 keeps it as a sticker. A photo or a meme is fitted into a square, whole, nothing cut. ⌥⌘V keeps it exactly as it is.")
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Label("Right-click a sticker to move it into a folder. Folders become sections, and you can search them by name.", systemImage: "folder")
                Label("To send one: fn F4, type, Enter. It is copied: paste it with ⌘V wherever you want.", systemImage: "paperplane")
            }
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Open F4", action: openF4)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 500)
    }
}

/// One step: its keys as keycaps, then what to do.
private struct Step: View {
    let keys: [String]
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { Keycap(label: $0) }
            }
            .frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct Keycap: View {
    let label: String

    var body: some View {
        Text(verbatim: label)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .frame(minWidth: 32, minHeight: 30)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
            )
    }
}
