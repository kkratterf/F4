import AppKit
import F4Core
import ImageIO
import SwiftUI

/// One GIPHY result in the grid, after the user's own memes.
///
/// Like `MemeCell`, it shows a still until it is hovered or selected, and
/// only then plays the small preview GIF. Images come from `GiphyClient`,
/// which keeps them in memory.
struct WebMemeCell: View {
    let result: Giphy.Result
    let giphy: GiphyClient
    let isSelected: Bool

    @State private var still: NSImage?
    @State private var isHovered = false
    @State private var animation: NSImage?

    private var shouldAnimate: Bool { isHovered || isSelected }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let animation, shouldAnimate {
                    AnimatedImageView(image: animation)
                } else if let still {
                    Image(nsImage: still)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .overlay(alignment: .bottom) {
                if isHovered || isSelected {
                    Text(verbatim: result.name)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .overlay(alignment: .topTrailing) {
                Text(verbatim: "GIPHY")
                    .font(.system(size: 8, weight: .heavy))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(.white)
                    .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .help(result.title)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: result.name))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .task(id: result.id) {
                still = nil
                // Without a still on GIPHY, the first frame of the preview.
                guard let data = await giphy.previewData(result.stillURL ?? result.previewURL),
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let frame = CGImageSourceCreateImageAtIndex(source, 0, nil)
                else { return }
                still = NSImage(cgImage: frame, size: .zero)
            }
            .task(id: shouldAnimate) {
                guard shouldAnimate else {
                    animation = nil
                    return
                }
                guard let data = await giphy.previewData(result.previewURL), !Task.isCancelled else { return }
                animation = NSImage(data: data)
            }
    }
}
