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
    let usage: UsageStore
    private var cancellables: Set<AnyCancellable> = []

    init(library: MemeLibrary, usage: UsageStore) {
        self.library = library
        self.usage = usage
        // The publishers fire before the new value is stored; refresh on the next turn.
        library.$memes.dropFirst().map { _ in () }
            .merge(with: usage.$favourites.dropFirst().map { _ in () })
            .sink { [weak self] _ in Task { @MainActor in self?.refresh(keepSelection: true) } }
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

    /// Called when the panel opens: start from a clean search, with the
    /// latest recents on top.
    func prepareForShow() {
        if query.isEmpty { refresh() } else { query = "" }
        selection = 0
        openCount += 1
    }

    /// Recomputes the results: favourites and recents first while the query
    /// is empty, best fuzzy matches otherwise.
    private func refresh(keepSelection: Bool = false) {
        let selected = selectedMeme
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            results = MemeOrdering.arrange(library.memes, favourites: usage.favourites, recents: usage.recents)
        } else {
            results = FuzzySearch.filter(library.memes, query: query)
        }
        if keepSelection, let selected, let index = results.firstIndex(of: selected) {
            selection = index
        } else {
            selection = 0
        }
    }
}
