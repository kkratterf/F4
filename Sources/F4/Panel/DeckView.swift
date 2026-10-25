import F4Core
import SwiftUI

/// The content of the panel: the search field on top, the memes below.
struct DeckView: View {
    @ObservedObject var model: DeckModel
    @ObservedObject var library: MemeLibrary
    /// The primary action: copy the meme and hide the panel.
    let onPick: (Meme) -> Void

    @FocusState private var searchFocused: Bool

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: DeckModel.columns
    )

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search memes", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .regular))
                    .focused($searchFocused)
                    .onSubmit {
                        if let meme = model.selectedMeme { onPick(meme) }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
        .onAppear { searchFocused = true }
        .onChange(of: model.openCount) { searchFocused = true }
    }

    @ViewBuilder
    private var content: some View {
        if let error = library.error {
            ContentUnavailableView(
                "Can't read the meme folder",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if library.memes.isEmpty {
            ContentUnavailableView(
                "No memes yet",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Drop GIFs, PNGs and JPEGs into \(library.folder.path(percentEncoded: false)).")
            )
        } else if model.results.isEmpty {
            ContentUnavailableView.search(text: model.query)
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, meme in
                        MemeCell(
                            meme: meme,
                            isSelected: index == model.selection,
                            isFavourite: model.usage.isFavourite(meme)
                        )
                        .id(meme.id)
                        .onTapGesture { onPick(meme) }
                        .contextMenu {
                            Button("Copy") { onPick(meme) }
                            Button(model.usage.isFavourite(meme)
                                ? LocalizedStringKey("Remove from Favourites")
                                : LocalizedStringKey("Add to Favourites")) {
                                model.usage.toggleFavourite(meme)
                            }
                            Divider()
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([meme.url])
                            }
                        }
                    }
                }
                .padding(14)
            }
            .onChange(of: model.selection) {
                if let meme = model.selectedMeme {
                    proxy.scrollTo(meme.id)
                }
            }
        }
    }
}

/// The translucent HUD material behind the panel content.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
