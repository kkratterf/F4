import Foundation

/// The image formats F4 shows and copies.
public enum MemeKind: String, CaseIterable, Sendable {
    case gif
    case png
    case jpeg

    /// The kind for a file URL, from its extension (case-insensitive), or nil
    /// when the file is not a meme F4 handles.
    public init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "gif": self = .gif
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        default: return nil
        }
    }

    /// Uniform Type Identifier of the raw file data, used on the pasteboard.
    public var typeIdentifier: String {
        switch self {
        case .gif: return "com.compuserve.gif"
        case .png: return "public.png"
        case .jpeg: return "public.jpeg"
        }
    }

    /// Whether the file can hold more than one frame.
    public var isAnimated: Bool { self == .gif }
}
