import AppKit
import F4Core
import SwiftUI

/// One square thumbnail in the grid.
///
/// Shows the cached thumbnail at once if there is one, otherwise decodes it
/// in the background (`ThumbnailCache`). Thumbnails are static: a GIF shows
/// its first frame, and plays only while the cell is selected. The mouse
/// selects the cell it moves over (`DeckModel.pointerMoved`), so there is
/// one highlighted cell, never a hovered one and a selected one.
struct MemeCell: View {
    /// Pixels for a 128 pt cell on a Retina display.
    static let thumbnailPixels = 256

    let meme: Meme
    let isSelected: Bool
    var isFavourite = false
    /// The star in the corner: adds or removes the favourite.
    var onToggleFavourite: (() -> Void)?

    /// With Reduce Motion on, a selected GIF shows its first frame and
    /// does not play. Copying it still copies the animation.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var image: CGImage?
    /// The full GIF, loaded only while the cell is selected.
    @State private var animation: NSImage?

    private var shouldAnimate: Bool {
        meme.kind.isAnimated && isSelected && !reduceMotion
    }

    /// What VoiceOver reads after the name: the folder, whether it is a
    /// favourite and whether it moves ("Reazioni, Favourite, Animated").
    private var accessibilityDetails: String {
        var parts: [String] = []
        if let category = meme.category { parts.append(category) }
        if isFavourite { parts.append(String(localized: "Favourite")) }
        if meme.kind.isAnimated { parts.append(String(localized: "Animated")) }
        if !meme.tags.isEmpty { parts.append(MemeTags.text(meme.tags)) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let animation, shouldAnimate {
                    AnimatedImageView(image: animation)
                } else if let image {
                    Image(decorative: image, scale: 2)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
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
            .overlay(alignment: .topLeading) {
                // Always there on a favourite, on the selected cell otherwise:
                // a click adds or removes the favourite without copying the meme.
                if isFavourite || isSelected {
                    Button {
                        onToggleFavourite?()
                    } label: {
                        Image(systemName: isFavourite ? "star.fill" : "star")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isFavourite ? Color.yellow : Color.white)
                            .shadow(color: .black.opacity(0.6), radius: 1.5)
                            .padding(5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onToggleFavourite == nil)
                    .help(isFavourite
                        ? LocalizedStringKey("Remove from Favourites")
                        : LocalizedStringKey("Add to Favourites"))
                    .accessibilityLabel(isFavourite
                        ? LocalizedStringKey("Remove from Favourites")
                        : LocalizedStringKey("Add to Favourites"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            }
            .contentShape(Rectangle())
            .help(meme.category.map { "\($0)/\(meme.name)" } ?? meme.name)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: meme.name))
            .accessibilityValue(Text(verbatim: accessibilityDetails))
            .accessibilityHint(Text("Copies the sticker"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: isFavourite
                ? Text("Remove from Favourites")
                : Text("Add to Favourites")) {
                onToggleFavourite?()
            }
            .task(id: meme) {
                if let cached = ThumbnailCache.shared.cached(meme, maxPixelSize: Self.thumbnailPixels) {
                    image = cached
                    await MainActor.run { PanelTiming.thumbnailShown() }
                    return
                }
                image = nil
                image = await ThumbnailCache.shared.thumbnail(for: meme, maxPixelSize: Self.thumbnailPixels)
                if image != nil { await MainActor.run { PanelTiming.thumbnailShown() } }
            }
            .task(id: shouldAnimate) {
                guard shouldAnimate else {
                    animation = nil
                    return
                }
                let url = meme.url
                // Read the file off the main thread; NSImageView decodes frames as it plays.
                let data = await Task.detached(priority: .userInitiated) {
                    try? Data(contentsOf: url, options: .mappedIfSafe)
                }.value
                guard !Task.isCancelled, let data else { return }
                animation = NSImage(data: data)
            }
    }
}
