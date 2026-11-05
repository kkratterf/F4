import Foundation

/// Fuzzy matching of a search query against meme names.
///
/// Every word of the query must appear in the name with its characters in
/// order, not necessarily next to each other ("tif" finds "this is fine").
/// Matches score higher when they are consecutive, start a word or start the
/// name. Case, accents and the separators `-`, `_` and `.` are ignored.
public enum FuzzySearch {
    /// `items` whose name matches `query`, best match first. Ties keep the
    /// original order. An empty query returns `items` unchanged.
    public static func filter<Item>(_ items: [Item], query: String, name: (Item) -> String) -> [Item] {
        filter(items, query: query, key: { normalized(name($0)) })
    }

    /// Memes whose name, subfolder or tags match `query`, best match first.
    /// Uses the key each meme worked out when it was scanned.
    public static func filter(_ memes: [Meme], query: String) -> [Meme] {
        filter(memes, query: query, key: \.searchKey)
    }

    private static func filter<Item>(_ items: [Item], query: String, key: (Item) -> [Int]) -> [Item] {
        let tokens = words(query)
        guard !tokens.isEmpty else { return items }
        var scored: [(index: Int, score: Int, item: Item)] = []
        for (index, item) in items.enumerated() {
            if let score = score(tokens: tokens, in: key(item)) {
                scored.append((index, score, item))
            }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        return scored.map(\.item)
    }

    /// Score of `query` against `candidate`, or nil when it does not match.
    public static func score(_ query: String, in candidate: String) -> Int? {
        let tokens = words(query)
        guard !tokens.isEmpty else { return 0 }
        return score(tokens: tokens, in: candidate)
    }

    // MARK: - Scoring

    private static let consecutiveBonus = 5
    private static let wordStartBonus = 8
    private static let nameStartBonus = 4
    private static let gapPenalty = 1

    private static func score(tokens: [[Int]], in candidate: String) -> Int? {
        score(tokens: tokens, in: normalized(candidate))
    }

    private static func score(tokens: [[Int]], in text: [Int]) -> Int? {
        // Most memes do not match: turn them down with a plain scan before
        // the scoring allocates anything.
        guard tokens.allSatisfy({ isSubsequence($0, of: text) }) else { return nil }
        var total = 0
        for token in tokens {
            guard let score = score(token: token, in: text) else { return nil }
            total += score
        }
        return total
    }

    private static func isSubsequence(_ token: [Int], of text: [Int]) -> Bool {
        var next = 0
        for code in text where next < token.count && code == token[next] {
            next += 1
        }
        return next == token.count
    }

    /// Best alignment of `token` as a subsequence of `text`, by dynamic
    /// programming over the places each token character occurs (a few
    /// per character, so far cheaper than every token × text pair).
    /// `previous` holds, for each place the last character matched, the
    /// best score of a match ending there.
    private static func score(token: [Int], in text: [Int]) -> Int? {
        let none = Int.min / 2
        var previous: [(position: Int, score: Int)] = []
        var current: [(position: Int, score: Int)] = []
        for (i, character) in token.enumerated() {
            current.removeAll(keepingCapacity: true)
            for j in text.indices where text[j] == character {
                var gain = 1
                if j == 0 || text[j - 1] == space { gain += wordStartBonus }
                if j == 0 { gain += nameStartBonus }
                if i == 0 {
                    current.append((j, gain))
                    continue
                }
                // Right after the previous character, or after a gap.
                var from = none
                for match in previous where match.position < j {
                    from = max(from, match.position == j - 1 ? match.score + consecutiveBonus : match.score - gapPenalty)
                }
                if from > none { current.append((j, from + gain)) }
            }
            guard !current.isEmpty else { return nil }
            swap(&previous, &current)
        }
        return previous.reduce(none) { max($0, $1.score) }
    }

    // MARK: - Normalisation

    /// A space, as `normalized` writes it.
    private static let space = 32

    private static func words(_ query: String) -> [[Int]] {
        normalized(query).split(separator: space).map(Array.init)
    }

    /// `string` as search compares it: case, accents and width folded,
    /// separators and whitespace turned into spaces, one number per
    /// character (comparing numbers is much cheaper than comparing
    /// `Character`s): its Unicode scalar, or a hash for the few characters
    /// made of several (some emoji).
    static func normalized(_ string: String) -> [Int] {
        let folded = string.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return folded.map { character in
            switch character {
            case "-", "_", ".": return space
            default:
                if character.isWhitespace { return space }
                let scalars = character.unicodeScalars
                if scalars.count == 1, let scalar = scalars.first { return Int(scalar.value) }
                // Above every scalar (0...0x10FFFF), so never equal to one.
                return 0x20_0000 + Int(UInt32(truncatingIfNeeded: character.hashValue))
            }
        }
    }
}
