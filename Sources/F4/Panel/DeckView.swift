import F4Core
import SwiftUI

/// The content of the panel: the search field on top, the memes below.
struct DeckView: View {
    @ObservedObject var model: DeckModel
    @ObservedObject var library: MemeLibrary
    /// The primary action: copy the meme and hide the panel.
    let onPick: (Meme) -> Void

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
                // F4 is named after the "F4, basito" face from Boris: the
                // placeholder stays Italian in every language, it's the joke.
                TextField(text: $model.query, prompt: Text(verbatim: "Cerca un F4 basito...")) {
                    Text("Search memes")
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .regular))
                    .focused($searchFocused)
                    .onSubmit {
                        if let meme = model.selectedMeme { onPick(meme) }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if let egg = model.easterEgg {
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
        .animation(.spring(duration: 0.3), value: model.easterEgg)
        .rotationEffect(.degrees(roll))
        .background(VisualEffectBackground(cornerRadius: FloatingPanel.cornerRadius))
        .clipShape(panelShape)
        // A hairline around the edge, as Raycast and Spotlight draw it.
        .overlay(panelShape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        .onAppear { searchFocused = true }
        .onChange(of: model.openCount) { searchFocused = true }
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
                Button {
                    model.usage.toggleFavourite(meme)
                } label: {
                    HStack(spacing: 6) {
                        Text(model.usage.isFavourite(meme)
                            ? LocalizedStringKey("Remove from Favourites")
                            : LocalizedStringKey("Add to Favourites"))
                        KeyHint(key: "⌘D")
                    }
                }
                .keyboardShortcut("d", modifiers: .command)
                Divider()
                    .frame(height: 16)
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
            } else {
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Color.primary.opacity(0.03))
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
            ContentUnavailableView {
                VStack(spacing: 10) {
                    BasitoFace(size: 120, custom: library.customBasito)
                    Text("No memes yet")
                }
            } description: {
                VStack(spacing: 4) {
                    Text(verbatim: "F4. Basito.")
                        .fontWeight(.semibold)
                    Text("Drop GIFs, PNGs and JPEGs into \(library.folder.path(percentEncoded: false)).")
                }
            }
        } else if model.results.isEmpty {
            if model.easterEgg?.effect == .basito {
                ContentUnavailableView {
                    BasitoFace(size: 140, custom: library.customBasito)
                } description: {
                    Text(verbatim: "F4. Basito.")
                }
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

/// A key as the footer shows it: "↵", "⌘D".
private struct KeyHint: View {
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
