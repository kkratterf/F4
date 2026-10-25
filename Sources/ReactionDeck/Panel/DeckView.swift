import SwiftUI

/// The content of the panel: the search field on top, the memes below.
struct DeckView: View {
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search memes", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .regular))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ContentUnavailableView(
                "No memes yet",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Your memes will show up here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
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
