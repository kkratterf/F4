import AppKit
import F4Core
import SwiftUI
import UniformTypeIdentifiers

/// "Add Stickers…" in the menu bar menu: a small window that stays open,
/// above other apps, so stickers can be dragged into it out of WhatsApp,
/// a browser or Finder one after the other. A click on it picks image
/// files in Finder instead. The panel can't do this: it closes as soon as
/// another app takes the focus, which is what it should do.
@MainActor
final class AddStickersWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let library: MemeLibrary
    private let model = AddStickersModel()

    init(library: MemeLibrary) {
        self.library = library
    }

    func show() {
        if window == nil {
            let view = AddStickersView(
                model: model,
                library: library,
                onChoose: { [weak self] in self?.chooseFiles() }
            )
            let hosting = DropHostingView(rootView: view)
            hosting.onDragChange = { [weak self] inside in self?.model.isTargeted = inside }
            hosting.onDrop = { [weak self] pasteboard in self?.add(from: pasteboard) }
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.contentView = hosting
            window.title = String(localized: "Add Stickers")
            // Above the app the stickers are dragged from, which takes the focus.
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        model.message = nil
        // An accessory app must activate itself, or the window opens behind the front app.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Where new stickers go: the folder picked in the window, else the top of the library.
    private var target: URL {
        guard let name = model.folder, library.folders.contains(name) else { return library.folder }
        return library.folder.appendingPathComponent(name, isDirectory: true)
    }

    private func add(from pasteboard: NSPasteboard) {
        let folder = target
        run { try await MemeImporter.importItems(from: pasteboard, into: folder) }
    }

    /// Finder's open panel, for images and sticker packs on the Mac.
    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.gif, .png, .jpeg, .webP]
            + [UTType(filenameExtension: "wastickers")].compactMap { $0 }
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.prompt = String(localized: "Add")
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            MainActor.assumeIsolated {
                guard let self, response == .OK, !panel.urls.isEmpty else { return }
                let urls = panel.urls
                let folder = self.target
                self.run { try await MemeImporter.importFiles(urls, into: folder) }
            }
        }
    }

    private func run(_ work: @escaping @MainActor () async throws -> [URL]) {
        model.isWorking = true
        Task {
            defer { model.isWorking = false }
            do {
                let urls = try await work()
                guard let first = urls.first else { return }
                library.reload()
                let folder = first.deletingLastPathComponent().lastPathComponent
                model.message = .added(urls.count == 1
                    ? String(localized: "Added to \(folder)")
                    : String(localized: "Added \(String(urls.count)) stickers to \(folder)"))
            } catch {
                model.message = .failed(error.localizedDescription)
            }
        }
    }
}

@MainActor
final class AddStickersModel: ObservableObject {
    enum Message: Equatable {
        case added(String)
        case failed(String)
    }

    /// The folder new stickers go into, nil for the top of the library.
    @Published var folder: String?
    @Published var isTargeted = false
    @Published var isWorking = false
    @Published var message: Message?
}

private struct AddStickersView: View {
    @ObservedObject var model: AddStickersModel
    @ObservedObject var library: MemeLibrary
    let onChoose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: onChoose) {
                VStack(spacing: 10) {
                    Image(systemName: model.isTargeted ? "arrow.down.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(model.isTargeted ? Color.accentColor : .secondary)
                    Text("Drop stickers here")
                        .font(.headline)
                    Text("Drag them out of WhatsApp, a browser or Finder, or click to choose images on your Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(model.isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            model.isTargeted ? Color.accentColor : Color.secondary.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isWorking)

            HStack(spacing: 8) {
                Picker("Add to", selection: $model.folder) {
                    Text("Top Level").tag(String?.none)
                    ForEach(library.folders, id: \.self) { folder in
                        Text(verbatim: folder).tag(String?.some(folder))
                    }
                }
                .fixedSize()
                Spacer(minLength: 8)
                if model.isWorking {
                    ProgressView().controlSize(.small)
                } else if let message = model.message {
                    switch message {
                    case .added(let text):
                        Label { Text(verbatim: text) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            .lineLimit(1)
                    case .failed(let text):
                        Text(verbatim: text)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
            }
            .font(.callout)
        }
        .padding(16)
        .frame(width: 360, height: 300)
    }
}
