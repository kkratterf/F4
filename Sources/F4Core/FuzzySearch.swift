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
        let tokens = words(query)
        guard !tokens.isEmpty else { return items }
        var scored: [(index: Int, score: Int, item: Item)] = []
        for (index, item) in items.enumerated() {
            if let score = score(tokens: tokens, in: name(item)) {
                scored.append((index, score, item))
            }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        return scored.map(\.item)
    }

    /// Memes whose name matches `query`, best match first.
    public static func filter(_ memes: [Meme], query: String) -> [Meme] {
        filter(memes, query: query, name: \.name)
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

    private static func score(tokens: [[Character]], in candidate: String) -> Int? {
        let text = normalized(candidate)
        var total = 0
        for token in tokens {
            guard let score = score(token: token, in: text) else { return nil }
            total += score
        }
        return total
    }

    /// Best alignment of `token` as a subsequence of `text`, by dynamic
    /// programming in O(token × text). `best[j]` is the best score with the
    /// current token character matched at `text[j]`.
    private static func score(token: [Character], in text: [Character]) -> Int? {
        let n = text.count
        guard token.count <= n else { return nil }
        let none = Int.min / 2
        var previous = [Int](repeating: none, count: n)
        for (i, character) in token.enumerated() {
            var current = [Int](repeating: none, count: n)
            // Best of previous[0..<j-1], i.e. a match after a gap.
            var bestBeforeGap = none
            for j in 0..<n {
                if j >= 2 { bestBeforeGap = max(bestBeforeGap, previous[j - 2]) }
                guard text[j] == character else { continue }
                var gain = 1
                if j == 0 || text[j - 1] == " " { gain += wordStartBonus }
                if j == 0 { gain += nameStartBonus }
                if i == 0 {
                    current[j] = gain
                } else {
                    let afterPrevious = j >= 1 && previous[j - 1] > none ? previous[j - 1] + consecutiveBonus : none
                    let afterGap = bestBeforeGap > none ? bestBeforeGap - gapPenalty : none
                    let from = max(afterPrevious, afterGap)
                    if from > none { current[j] = from + gain }
                }
            }
            previous = current
        }
        let best = previous.max() ?? none
        return best > none ? best : nil
    }

    // MARK: - Normalisation

    private static func words(_ query: String) -> [[Character]] {
        String(normalized(query)).split(separator: " ").map(Array.init)
    }

    private static func normalized(_ string: String) -> [Character] {
        let folded = string.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return folded.map { character in
            switch character {
            case "-", "_", ".": return " "
            default: return character.isWhitespace ? " " : character
            }
        }
    }
}
