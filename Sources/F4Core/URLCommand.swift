import Foundation

/// What an `f4://` URL asks F4 to do, so Shortcuts, Raycast, Alfred, a
/// Stream Deck, the terminal (`open "f4://copy?name=this%20is%20fine"`) or an
/// AI agent can drive the app.
///
/// | URL | Command |
/// | --- | --- |
/// | `f4://open` | show the panel |
/// | `f4://search?q=…` | show the panel with the query typed in |
/// | `f4://copy?name=…` | copy the best match, without showing the panel |
/// | `f4://reload` | rescan the meme folder |
/// | `f4://settings` | open the menu bar menu, where the options are |
///
/// Commands are case-insensitive; `f4:open` and a trailing slash work too.
public enum URLCommand: Equatable, Sendable {
    case open
    case search(String)
    case copy(String)
    case reload
    case settings

    /// The URL scheme, registered in `Resources/Info.plist` (`CFBundleURLTypes`).
    public static let scheme = "f4"

    /// The command `url` asks for, or nil when it is not an `f4:` URL, names
    /// no known command, or is a copy without a name.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        // f4://open puts the command in the host, f4:open in the path.
        let raw = components.host ?? components.path
        let command = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let items = components.queryItems ?? []
        func value(_ names: String...) -> String? {
            for name in names {
                if let value = items.first(where: { $0.name.lowercased() == name })?.value {
                    // A form-encoded "+" is a space ("this+is+fine").
                    return value.replacingOccurrences(of: "+", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return nil
        }
        switch command {
        case "", "open", "show":
            self = .open
        case "search":
            self = .search(value("q", "query") ?? "")
        case "copy":
            guard let name = value("name", "q", "query"), !name.isEmpty else { return nil }
            self = .copy(name)
        case "reload", "rescan":
            self = .reload
        case "settings", "preferences":
            self = .settings
        default:
            return nil
        }
    }

    /// The meme `f4://copy` copies for `name`: the best fuzzy match, with
    /// favourites and then recents winning a tie, as in the panel. Nil when
    /// nothing matches.
    public static func bestMatch(for name: String, in memes: [Meme], favourites: Set<URL>, recents: [URL]) -> Meme? {
        let arranged = MemeOrdering.arrange(memes, favourites: favourites, recents: recents)
        return FuzzySearch.filter(arranged, query: name).first
    }
}
