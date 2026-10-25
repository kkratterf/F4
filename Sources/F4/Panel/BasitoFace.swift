import AppKit
import SwiftUI

/// The *F4, basito* face from Boris: raised eyebrows, round eyes, mouth open.
///
/// Drawn in code, like the app icon of the Raycast extension: no stills from
/// the show in the repo. A user image at `<meme folder>/.basito.png` (or
/// `.gif`, `.jpg`) replaces it, for those who want the real Stanis.
struct BasitoFace: View {
    var size: CGFloat = 120
    /// The user's own basito image, if any.
    var custom: URL?

    @State private var customImage: NSImage?

    var body: some View {
        Group {
            if let customImage {
                AnimatedImageView(image: customImage)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
            } else {
                drawnFace
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(verbatim: "F4, basito"))
        .task(id: custom) {
            guard let custom else {
                customImage = nil
                return
            }
            let data = await Task.detached { try? Data(contentsOf: custom, options: .mappedIfSafe) }.value
            customImage = data.flatMap(NSImage.init(data:))
        }
    }

    private var drawnFace: some View {
        Canvas { context, canvas in
            let s = min(canvas.width, canvas.height) / 512
            func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
                CGRect(x: x0 * s, y: y0 * s, width: (x1 - x0) * s, height: (y1 - y0) * s)
            }
            let ink = Color(red: 0.24, green: 0.16, blue: 0.12)
            let line = 9 * s

            context.fill(Path(roundedRect: rect(16, 16, 496, 496), cornerRadius: 110 * s), with: .color(Color(red: 1, green: 0.77, blue: 0.24)))
            let face = Path(ellipseIn: rect(96, 90, 416, 440))
            context.fill(face, with: .color(Color(red: 0.98, green: 0.88, blue: 0.77)))
            context.stroke(face, with: .color(ink), lineWidth: line)

            // Hair: the top half of an ellipse.
            var hair = Path()
            hair.addArc(center: CGPoint(x: 256 * s, y: 145 * s), radius: 160 * s,
                        startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            hair.closeSubpath()
            context.fill(hair.applying(CGAffineTransform(translationX: 0, y: 145 * s).scaledBy(x: 1, y: 0.66).translatedBy(x: 0, y: -145 * s)),
                         with: .color(Color(red: 0.36, green: 0.25, blue: 0.16)))

            // Eyebrows raised as high as they go.
            for x in [195.0, 317.0] {
                var brow = Path()
                brow.addArc(center: CGPoint(x: x * s, y: 208 * s), radius: 44 * s,
                            startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
                context.stroke(brow, with: .color(ink), style: StrokeStyle(lineWidth: 12 * s, lineCap: .round))
                let eye = Path(ellipseIn: rect(x - 38, 222, x + 38, 302))
                context.fill(eye, with: .color(.white))
                context.stroke(eye, with: .color(ink), lineWidth: line)
                context.fill(Path(ellipseIn: rect(x - 11, 252, x + 11, 274)), with: .color(Color(white: 0.12)))
            }

            let mouth = Path(ellipseIn: rect(230, 350, 282, 398))
            context.fill(mouth, with: .color(Color(red: 0.47, green: 0.16, blue: 0.16)))
            context.stroke(mouth, with: .color(ink), lineWidth: line)
        }
    }
}
