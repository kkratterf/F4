import F4Core
import SwiftUI

/// One square thumbnail in the grid.
///
/// Shows the cached thumbnail at once if there is one, otherwise decodes it
/// in the background (`ThumbnailCache`). Thumbnails are static: a GIF shows
/// its first frame.
struct MemeCell: View {
    /// Pixels for a 128 pt cell on a Retina display.
    static let thumbnailPixels = 256

    let meme: Meme
    let isSelected: Bool

    @State private var image: CGImage?
    @State private var isHovered = false

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 2)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .overlay(alignment: .bottom) {
                if isHovered || isSelected {
                    Text(meme.name)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .overlay(alignment: .topTrailing) {
                if meme.kind.isAnimated {
                    Text(verbatim: "GIF")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.white)
                        .padding(5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .help(meme.name)
            .accessibilityElement()
            .accessibilityLabel(meme.name)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .task(id: meme) {
                if let cached = ThumbnailCache.shared.cached(meme, maxPixelSize: Self.thumbnailPixels) {
                    image = cached
                    return
                }
                image = nil
                image = await ThumbnailCache.shared.thumbnail(for: meme, maxPixelSize: Self.thumbnailPixels)
            }
    }
}
