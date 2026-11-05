import F4Core
import SwiftUI

/// The content of the panel: the search field on top, the memes below.
struct DeckView: View {
    @ObservedObject var model: DeckModel
    @ObservedObject var library: MemeLibrary
    /// ⌘K and ⌘M: the actions over the panel.
    @ObservedObject var palette: ActionPalette
    /// The primary action: copy the meme and hide the panel.
    let onPick: (Meme) -> Void
    /// The + button: pick files to add.
    let onAdd: () -> Void
    /// The ⓘ button: how to add stickers.
    let onHelp: () -> Void
    /// The footer's Actions button: what ⌘K opens.
    let onActions: () -> Void
    /// The user drags the panel by its search bar or footer.
    let onDrag: (PanelDrag) -> Void
    /// Move, rename or trash a meme from its right-click menu.
    let onOrganize: (Meme, MemeAction) -> Void

    @FocusState private var searchFocused: Bool
    /// Degrees the panel content has spun for "do a barrel roll".
    @State private var roll = 0.0

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
                TextField(text: $model.query, prompt: Text("Search…")) {
                    Text("Search stickers")
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .regular))
                    .focused($searchFocused)
                    .onSubmit {
                        if let meme = model.selectedMeme {
                            onPick(meme)
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(WindowDragArea(onDrag: onDrag))

            TabBar(selection: $model.tab, tabs: model.tabs, onAdd: onAdd, onHelp: onHelp)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if let notice = model.notice {
                Text(verbatim: notice)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.2), in: Capsule())
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let egg = model.easterEgg {
                Text(verbatim: egg.banner)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.2), in: Capsule())
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) {
            if palette.isOpen {
                ActionPaletteView(palette: palette)
                    .padding(.trailing, 10)
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottomTrailing)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: palette.isOpen)
        .animation(.spring(duration: 0.3), value: model.easterEgg)
        .animation(.spring(duration: 0.3), value: model.notice)
        .rotationEffect(.degrees(roll))
        .background(VisualEffectBackground(cornerRadius: FloatingPanel.cornerRadius))
        .clipShape(panelShape)
        // A hairline around the edge, as Raycast and Spotlight draw it.
        .overlay(panelShape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        .onAppear { searchFocused = true }
        .onChange(of: model.openCount) { searchFocused = true }
        .onChange(of: palette.isOpen) { if !palette.isOpen { searchFocused = true } }
        .onChange(of: model.easterEgg) {
            if model.easterEgg?.effect == .barrelRoll {
                withAnimation(.easeInOut(duration: 1.1)) { roll += 360 }
            }
        }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FloatingPanel.cornerRadius, style: .continuous)
    }

    /// The bar at the bottom, like Raycast's: the selected meme on the left,
    /// what the keys do with it on the right.
    private var footer: some View {
        HStack(spacing: 10) {
            if let meme = model.selectedMeme {
                Text(verbatim: meme.category.map { "\($0)/\(meme.name)" } ?? meme.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                // Enter is handled by the search field; this is for the mouse.
                Button {
                    onPick(meme)
                } label: {
                    HStack(spacing: 6) {
                        Text("Copy")
                            .fontWeight(.medium)
                        KeyHint(key: "↵")
                    }
                }
                Divider()
                    .frame(height: 16)
                // ⌘K is handled by PanelController's key monitor; this is for the mouse.
                Button(action: onActions) {
                    HStack(spacing: 6) {
                        Text("Actions")
                        KeyHint(key: "⌘K")
                    }
                }
            } else {
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(WindowDragArea(onDrag: onDrag))
        .background(Color.primary.opacity(0.03))
    }

    @ViewBuilder
    private var content: some View {
        if let error = library.error {
            ContentUnavailableView(
                "Can't read the sticker folder",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if library.memes.isEmpty {
            ContentUnavailableView {
                VStack(spacing: 10) {
                    BasitoFace(size: 120, custom: library.customBasito)
                    Text("No stickers yet")
                }
            } description: {
                VStack(spacing: 4) {
                    Text(verbatim: "F4. Basito.")
                        .fontWeight(.semibold)
                    Text("Paste a sticker or a link with ⌘V, drop files here, or click Add. They are saved in \(library.folder.path(percentEncoded: false)).")
                }
            }
        } else if model.results.isEmpty {
            if model.easterEgg?.effect == .basito {
                ContentUnavailableView {
                    BasitoFace(size: 140, custom: library.customBasito)
                } description: {
                    Text(verbatim: "F4. Basito.")
                }
            } else if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                emptyTab
            } else {
                ContentUnavailableView.search(text: model.query)
            }
        } else {
            VStack(spacing: 0) {
                if model.easterEgg?.effect == .basito {
                    BasitoFace(size: 64, custom: library.customBasito)
                        .padding(.top, 10)
                }
                effects(on: grid)
            }
        }
    }

    /// A tab with nothing in it while the meme folder has memes.
    @ViewBuilder
    private var emptyTab: some View {
        switch model.tab {
        case .favourites:
            ContentUnavailableView(
                "No favourites yet",
                systemImage: "star",
                description: Text("Click the star on a sticker, or select it and press ⌘D, to keep it here. Do it again to remove it.")
            )
        case .folder where model.query.trimmingCharacters(in: .whitespaces).isEmpty:
            ContentUnavailableView(
                "This folder is empty",
                systemImage: "folder",
                description: Text("Paste a sticker here with ⌘V, or select one in another tab and press ⌘M to move it in.")
            )
        case .all, .folder:
            ContentUnavailableView.search(text: model.query)
        }
    }

    /// The grid as an easter egg wants it.
    @ViewBuilder
    private func effects(on grid: some View) -> some View {
        switch model.easterEgg?.effect {
        case .smarmella:
            // René: "apri tutto, smarmella!" Everything overexposed.
            grid.brightness(0.3).saturation(1.5).contrast(0.85)
        case .parkour:
            grid.phaseAnimator([false, true]) { content, up in
                content.offset(y: up ? -10 : 0)
            } animation: { _ in .easeInOut(duration: 0.22) }
        case .rainbow:
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                grid.hueRotation(.degrees(context.date.timeIntervalSinceReferenceDate * 120))
            }
        default:
            grid
        }
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    // Each section starts on a new row, which is what
                    // `DeckModel.sections` tells the arrow keys.
                    if model.favouriteCount > 0 {
                        Section {
                            memeCells(0..<model.favouriteCount)
                        } header: {
                            SectionHeader(title: "Favourites")
                        }
                        Section {
                            memeCells(model.favouriteCount..<model.results.count)
                        } header: {
                            SectionHeader(title: "Everything else")
                        }
                    } else {
                        memeCells(model.results.indices)
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

extension DeckView {
    /// The cells of `model.results` in `range`.
    fileprivate func memeCells(_ range: Range<Int>) -> some View {
        ForEach(Array(model.results[range].enumerated()), id: \.element.id) { offset, meme in
            memeCell(meme, at: range.lowerBound + offset)
        }
    }

    private func memeCell(_ meme: Meme, at index: Int) -> some View {
        MemeCell(
            meme: meme,
            isSelected: index == model.selection,
            isFavourite: model.usage.isFavourite(meme),
            onToggleFavourite: { model.usage.toggleFavourite(meme) }
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
            // Starter memes listed from the app bundle can't be changed.
            if !library.isStarter(meme) {
                Divider()
                Menu("Move To") {
                    if meme.category != nil {
                        Button("Top Level") { onOrganize(meme, .move(to: nil)) }
                    }
                    ForEach(library.folders.filter { $0 != meme.category }, id: \.self) { folder in
                        Button(folder) { onOrganize(meme, .move(to: folder)) }
                    }
                    Divider()
                    Button("New Folder…") { onOrganize(meme, .moveToNewFolder) }
                }
                Button("Rename…") { onOrganize(meme, .rename) }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([meme.url])
                }
                Divider()
                Button("Move to Trash") { onOrganize(meme, .trash) }
            }
        }
    }
}

/// A heading over a section of the grid: "Favourites", "Everything else".
private struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

/// Stickers · Favourites · each folder, under the search field. Tab and
/// ⌘1…⌘9 switch too (`PanelController`).
private struct TabBar: View {
    @Binding var selection: MemeTab
    let tabs: [MemeTab]
    let onAdd: () -> Void
    let onHelp: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tabs, id: \.self) { tab in
                            chip(tab).id(tab)
                        }
                    }
                }
                .onChange(of: selection) { proxy.scrollTo(selection) }
            }
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Add stickers. You can also paste them with ⌘V or drop them here.")
            Button(action: onHelp) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("How to add stickers")
            .accessibilityLabel(Text("How to add stickers"))
        }
    }

    private func chip(_ tab: MemeTab) -> some View {
        Button {
            selection = tab
        } label: {
            Self.title(tab)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    selection == tab ? Color.accentColor.opacity(0.25) : Color.clear,
                    in: Capsule()
                )
                .foregroundStyle(selection == tab ? .primary : .secondary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    private static func title(_ tab: MemeTab) -> Text {
        switch tab {
        case .all: return Text("Stickers")
        case .favourites: return Text("Favourites")
        case .folder(let name): return Text(verbatim: name)
        }
    }
}

/// A key as the footer and the action palette show it: "↵", "⌘K".
struct KeyHint: View {
    let key: String

    var body: some View {
        Text(verbatim: key)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, key.count > 1 ? 4 : 0)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// The translucent HUD material behind the panel content, cut to the
/// panel's rounded shape.
///
/// A behind-window material ignores layer masks and SwiftUI clipping; its
/// `maskImage` is the one shape it follows. The mask is a small rounded
/// square whose corners stay fixed while its middle stretches.
private struct VisualEffectBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.mask(cornerRadius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    private static func mask(cornerRadius radius: CGFloat) -> NSImage {
        // A continuous corner curves further along each edge than its radius.
        let cap = ceil(radius * 1.6)
        let side = cap * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.capInsets = NSEdgeInsets(top: cap, left: cap, bottom: cap, right: cap)
        image.resizingMode = .stretch
        return image
    }
}
