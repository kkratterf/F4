import Foundation

/// Tags as people type and read them: "gatto, reazione, lunedì".
public enum MemeTags {
    /// The tags in what was typed: split on commas, trimmed, spaces
    /// collapsed, at most 40 characters each, duplicates dropped ignoring
    /// case and accents, in the order typed.
    public static func parse(_ typed: String) -> [String] {
        var seen: Set<String> = []
        var tags: [String] = []
        for part in typed.split(separator: ",") {
            let tag = String(part.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(40))
            let key = tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            guard !tag.isEmpty, seen.insert(key).inserted else { continue }
            tags.append(tag)
        }
        return tags
    }

    /// The tags as one line to edit: "gatto, reazione".
    public static func text(_ tags: [String]) -> String {
        tags.joined(separator: ", ")
    }
}
