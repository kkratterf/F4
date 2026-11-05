import SwiftUI

/// The list of actions over the panel, like Raycast's ⌘K: the actions for
/// the selected sticker, or the folders to move it to (⌘M). Typing filters
/// it, the arrow keys move in it, Enter runs, Escape closes. The keys come
/// from `PanelController`'s key monitor; this holds the state.
@MainActor
final class ActionPalette: ObservableObject {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
        /// The key that runs it without the palette, shown on the right ("⌘M").
        var shortcut: String?
        var isDestructive = false
        let run: () -> Void
    }

    /// The palette's heading ("Actions", "Move to"); nil while it is closed.
    @Published private(set) var title: String?
    @Published private(set) var items: [Item] = []
    @Published var filter = "" {
        didSet { if filter != oldValue { selection = 0 } }
    }
    @Published var selection = 0
    /// Bumped on every open, so the view focuses the filter field.
    @Published private(set) var openCount = 0

    var isOpen: Bool { title != nil }

    /// The items whose title contains what was typed.
    var visible: [Item] {
        let typed = filter.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(typed) }
    }

    func open(title: String, items: [Item]) {
        self.title = title
        self.items = items
        filter = ""
        selection = 0
        openCount += 1
    }

    func close() {
        title = nil
        items = []
        filter = ""
    }

    func move(by delta: Int) {
        let count = visible.count
        guard count > 0 else { return }
        selection = (selection + delta + count) % count
    }

    /// Runs the selected item. The palette closes first, so an item can open
    /// it again with another list ("Move to…").
    func runSelected() {
        let list = visible
        guard list.indices.contains(selection) else { return }
        let item = list[selection]
        close()
        item.run()
    }

    func run(_ item: Item) {
        close()
        item.run()
    }
}

/// The palette as the panel shows it: a card in the bottom right corner,
/// above the footer, as in Raycast.
struct ActionPaletteView: View {
    @ObservedObject var palette: ActionPalette
    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = palette.title {
                Text(verbatim: title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        let list = palette.visible
                        ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                            row(item, selected: index == palette.selection)
                                .id(item.id)
                                .onTapGesture { palette.run(item) }
                        }
                        if list.isEmpty {
                            Text("No matches")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 260)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: palette.selection) {
                    let list = palette.visible
                    if list.indices.contains(palette.selection) {
                        proxy.scrollTo(list[palette.selection].id)
                    }
                }
            }
            Divider()
                .padding(.top, 6)
            TextField(text: $palette.filter, prompt: Text("Search…")) {
                Text("Search actions")
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($filterFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .frame(width: 290)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 18, y: 6)
        .onAppear { filterFocused = true }
        .onChange(of: palette.openCount) { filterFocused = true }
    }

    private func row(_ item: ActionPalette.Item, selected: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: item.systemImage)
                .frame(width: 16)
                .foregroundStyle(item.isDestructive ? Color.red : Color.secondary)
            Text(verbatim: item.title)
                .foregroundStyle(item.isDestructive ? Color.red : Color.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let shortcut = item.shortcut {
                KeyHint(key: shortcut)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            selected ? Color.accentColor.opacity(0.22) : Color.clear,
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .contentShape(Rectangle())
    }
}
