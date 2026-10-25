import Combine
import F4Core
import Foundation

/// State of the panel: the query, the memes that match it and the selected one.
@MainActor
final class DeckModel: ObservableObject {
    /// Grid columns. Fixed, so keyboard navigation knows what a row is.
    static let columns = 5

    @Published var query = "" {
        didSet { if query != oldValue { refresh() } }
    }
    @Published private(set) var results: [Meme] = []
    /// Index into `results`. Reset to the best match whenever the results change.
    @Published var selection = 0
    /// Bumped every time the panel opens, so the view focuses the search field.
    @Published private(set) var openCount = 0

    let library: MemeLibrary
    private var cancellables: Set<AnyCancellable> = []

    init(library: MemeLibrary) {
        self.library = library
        library.$memes
            .dropFirst()
            .sink { [weak self] _ in
                // $memes fires before the value is stored; refresh on the next turn.
                Task { @MainActor in self?.refresh() }
            }
            .store(in: &cancellables)
        refresh()
    }

    var selectedMeme: Meme? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    /// Moves the selection in the grid. Returns false when there is nothing to select.
    @discardableResult
    func move(_ direction: GridDirection) -> Bool {
        guard !results.isEmpty else { return false }
        selection = GridNavigation.move(direction, from: selection, count: results.count, columns: Self.columns)
        return true
    }

    /// Called when the panel opens: start from a clean search.
    func prepareForShow() {
        query = ""
        selection = 0
        openCount += 1
    }

    private func refresh() {
        results = FuzzySearch.filter(library.memes, query: query)
        selection = 0
    }
}
