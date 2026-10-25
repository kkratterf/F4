import AppKit
import F4Core

/// Puts a meme on the system clipboard so it pastes as the original file.
///
/// Writing an `NSImage` would flatten a GIF to one frame. Instead one
/// pasteboard item carries the file URL and the raw file bytes under the
/// file's UTI (`MemeKind.pasteboardTypes`), so Slack, Discord and Telegram
/// upload the animated GIF, and image editors still get the bytes.
enum MemeClipboard {
    @discardableResult
    static func copy(_ meme: Meme, to pasteboard: NSPasteboard = .general) -> Bool {
        let item = NSPasteboardItem()
        for type in meme.kind.pasteboardTypes {
            let pasteboardType = NSPasteboard.PasteboardType(type)
            if pasteboardType == .fileURL {
                item.setString(meme.url.absoluteString, forType: pasteboardType)
            } else if let data = try? Data(contentsOf: meme.url, options: .mappedIfSafe) {
                item.setData(data, forType: pasteboardType)
            }
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }
}
