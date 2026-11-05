import XCTest
@testable import F4Core

/// The work the panel does on the main thread, with a library of 5,000
/// stickers: arranging the grid when it opens and searching as the user
/// types. Each must fit well inside the 100 ms the panel has to open in.
/// The times are printed in every build and held to the budget in an
/// optimized one, as the app is built (CI runs `swift test -c release`).
final class LargeLibraryTests: XCTestCase {
    #if DEBUG
    private static let isOptimized = false
    #else
    private static let isOptimized = true
    #endif

    private static let budget = 50.0

    private static let words = [
        "gatto", "triste", "risata", "boh", "ti prego", "shock", "ok", "dai dai dai",
        "this is fine", "basito", "perché", "facepalm", "applausi", "nope", "sì",
    ]
    private static let folders: [String?] = [nil, "Emoji", "maramao", "Reazioni", "Reazioni/cani", "Boris"]

    private static let memes: [Meme] = (0..<5_000).map { index in
        let name = "\(words[index % words.count]) \(index)"
        let folder = folders[index % folders.count]
        let url = URL(fileURLWithPath: "/m/\(folder.map { "\($0)/" } ?? "")\(name).png")
        let tags = index % 3 == 0 ? [words[(index / 3) % words.count]] : []
        return Meme(url: url, kind: .png, modificationDate: .distantPast, category: folder, tags: tags)
    }

    /// Milliseconds `work` takes, the best of three runs.
    private func milliseconds(_ work: () -> Void) -> Double {
        (0..<3).map { _ in
            let start = DispatchTime.now().uptimeNanoseconds
            work()
            return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        }.min() ?? 0
    }

    func testSearchingTheMemesMatchesSearchingTheirText() {
        let memes = Self.memes
        for query in ["ga", "gatto tri", "reazioni cani", "perche", "xyz", "b 49"] {
            XCTAssertEqual(
                FuzzySearch.filter(memes, query: query).map(\.url),
                FuzzySearch.filter(memes, query: query, name: \.searchText).map(\.url),
                query
            )
        }
    }

    func testArrangingFiveThousandStickersIsQuick() {
        let memes = Self.memes
        let favourites = Set(memes.prefix(40).map(\.url))
        let recents = memes.suffix(30).map(\.url)
        let elapsed = milliseconds {
            _ = MemeTab.all.filter(memes, favourites: favourites)
            _ = MemeOrdering.arrange(memes, favourites: favourites, recents: recents)
        }
        print("Arranging 5,000 stickers: \(String(format: "%.1f", elapsed)) ms")
        if Self.isOptimized { XCTAssertLessThan(elapsed, Self.budget) }
    }

    func testSearchingFiveThousandStickersIsQuick() {
        let memes = Self.memes
        // As typed, a key at a time, plus a query nothing matches.
        for query in ["g", "ga", "gat", "gatto t", "gatto tri", "reazioni", "zzz"] {
            let elapsed = milliseconds { _ = FuzzySearch.filter(memes, query: query) }
            print("Searching 5,000 stickers for \"\(query)\": \(String(format: "%.1f", elapsed)) ms")
            if Self.isOptimized { XCTAssertLessThan(elapsed, Self.budget, query) }
        }
    }
}
