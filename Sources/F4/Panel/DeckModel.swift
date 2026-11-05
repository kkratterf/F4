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
    /// The tab the panel shows. Remembered between launches.
    @Published var tab: MemeTab {
        didSet {
            guard tab != oldValue else { return }
            defaults.set(tab.rawValue, forKey: Self.tabKey)
            refresh()
        }
    }
    @Published private(set) var results: [Meme] = []
    /// How many of the first `results` are favourites shown under their own
    /// "Favourites" heading: with an empty search, outside the Favourites tab.
    /// 0 when the grid has no sections.
    @Published private(set) var favouriteCount = 0
    /// Index into `results`. Reset to the best
    /// match whenever the results change.
    @Published var selection = 0
    /// Bumped every time the panel opens, so the view focuses the search field.
    @Published private(set) var openCount = 0
    /// The easter egg typed in the search field (or the Konami code), if any.
    @Published private(set) var easterEgg: EasterEgg?

    /// A short message under the search field ("Added to Stickers", or why
    /// an import failed). Clears itself after a few seconds.
    @Published private(set) var notice: String?
    private var noticeTask: Task<Void, Never>?
    /// A meme just added from the panel, selected as soon as the scan sees it.
    private var pendingReveal: URL?

    private var konami = KonamiCode()
    private var konamiActive = false

    let library: MemeLibrary
    let usage: UsageStore
    private let defaults: UserDefaults
    private static let tabKey = "panelTab"
    private var cancellables: Set<AnyCancellable> = []

    init(library: MemeLibrary, usage: UsageStore, defaults: UserDefaults = .standard) {
        self.library = library
        self.usage = usage
        self.defaults = defaults
        tab = defaults.string(forKey: Self.tabKey).flatMap(MemeTab.init(rawValue:)) ?? .all
        // A folder tab whose folder is gone (renamed, trashed) goes back to All.
        library.$folders.dropFirst()
            .sink { [weak self] folders in
                Task { @MainActor in
                    guard let self, !MemeTab.tabs(folders: folders).contains(self.tab) else { return }
                    self.tab = .all
                }
            }
            .store(in: &cancellables)
        // The publishers fire before the new value is stored; refresh on the next turn.
        library.$memes.dropFirst().map { _ in () }
            .merge(with: usage.$favourites.dropFirst().map { _ in () })
            .sink { [weak self] _ in Task { @MainActor in self?.refresh(keepSelection: true) } }
            .store(in: &cancellables)
        refresh()
    }

    /// What the grid shows.
    var itemCount: Int { results.count }

    /// The sizes of the grid's sections, in order: favourites and the rest
    /// (or all results). Each section starts on a new row.
    var sections: [Int] {
        favouriteCount > 0 ? [favouriteCount, results.count - favouriteCount] : [results.count]
    }

    var selectedMeme: Meme? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    /// Where the mouse was the last time it moved over a cell.
    private var pointer: CGPoint?

    /// The mouse moved over the cell at `index`: it becomes the selection,
    /// as in Raycast. Only when the mouse itself moved, so a grid that the
    /// arrow keys scroll under a still pointer keeps the keyboard's choice.
    func pointerMoved(to location: CGPoint, over index: Int) {
        defer { pointer = location }
        guard let pointer, pointer != location, results.indices.contains(index) else { return }
        selection = index
    }

    /// Moves the selection in the grid. Returns false when there is nothing to select.
    @discardableResult
    func move(_ direction: GridDirection) -> Bool {
        guard itemCount > 0 else { return false }
        selection = GridNavigation.move(direction, from: selection, sections: sections, columns: Self.columns)
        return true
    }

    /// Shows `message` under the search field for a few seconds.
    func show(notice message: String) {
        notice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    /// Selects `url` once it is in the library: called after an import, before
    /// the folder watcher has picked the file up. Clears the search and
    /// switches to All when the current tab would not show it.
    func reveal(_ url: URL) {
        pendingReveal = url.standardizedFileURL
        if !query.isEmpty { query = "" }
        refresh()
    }

    /// The tabs: Stickers, Favourites, then one per top-level folder.
    var tabs: [MemeTab] { MemeTab.tabs(folders: library.folders) }

    /// Tab and ⇧Tab: the next or previous tab.
    func cycleTab(backwards: Bool) {
        tab = tab.next(in: tabs, backwards: backwards)
    }

    /// ⌘1…⌘9: the tab at `index` (0 is Stickers), when there is one.
    func selectTab(at index: Int) {
        let tabs = tabs
        if tabs.indices.contains(index) { tab = tabs[index] }
    }

    /// Feeds every key press in the panel to the Konami code detector.
    func feedKonami(_ key: KonamiCode.Key) {
        guard konami.feed(key) else { return }
        konamiActive = true
        // The B and A went into the search field.
        if query.isEmpty { refresh() } else { query = "" }
    }

    /// Called when the panel opens: start from a clean search, with the
    /// latest recents on top.
    func prepareForShow() {
        konamiActive = false
        if query.isEmpty { refresh() } else { query = "" }
        selection = 0
        pointer = nil
        openCount += 1
    }

    /// Recomputes the results from the memes of the current tab: favourites
    /// and recents first while the query is empty, best fuzzy matches otherwise.
    private func refresh(keepSelection: Bool = false) {
        let selected = selectedMeme
        let egg = query.isEmpty && konamiActive ? EasterEggs.konami : EasterEggs.match(query)
        if easterEgg != egg { easterEgg = egg }
        let memes = tab.filter(library.memes, favourites: usage.favourites)
        let arranged = { MemeOrdering.arrange(memes, favourites: self.usage.favourites, recents: self.usage.recents) }
        if let egg, egg.showsAllMemes {
            switch egg.effect {
            case .favouritesOnly:
                results = arranged().filter { usage.favourites.contains($0.url) }
            case .shuffle:
                results = memes.shuffled()
            default:
                results = arranged()
            }
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            results = arranged()
        } else {
            results = FuzzySearch.filter(memes, query: query)
        }
        // Favourites get their own heading on the home grid, so it is clear
        // where they are; the Favourites tab and search results have none.
        let sectioned = egg == nil && tab != .favourites && query.trimmingCharacters(in: .whitespaces).isEmpty
        let count = sectioned ? results.prefix { usage.favourites.contains($0.url) }.count : 0
        // A heading over everything would add nothing.
        favouriteCount = count < results.count ? count : 0
        if let pendingReveal, let meme = library.memes.first(where: { $0.url.standardizedFileURL == pendingReveal }) {
            if !tab.contains(meme, favourites: usage.favourites) {
                // Setting the tab refreshes again and lands in the branch below.
                tab = .all
                return
            }
            if let index = results.firstIndex(of: meme) {
                self.pendingReveal = nil
                selection = index
                return
            }
        }
        if keepSelection, let selected, let index = results.firstIndex(of: selected) {
            selection = index
        } else if keepSelection, selected != nil, !results.isEmpty {
            // The selected meme left this tab (unfavourited in Favourites,
            // moved out of a folder): stay where it was.
            selection = min(selection, results.count - 1)
        } else if egg?.effect == .randomPick, !results.isEmpty {
            selection = Int.random(in: results.indices)
        } else {
            selection = 0
        }
    }
}
