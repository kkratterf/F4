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
    /// The GIPHY row after the local results, in the GIFs and Stickers tabs.
    @Published private(set) var webResults: [Giphy.Result] = []
    /// Index into `results` followed by `webResults`. Reset to the best
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
    let giphy: GiphyClient
    /// Tab and query of the last GIPHY request, so only a change asks again.
    private var webRequest: String?
    private var webTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private static let tabKey = "panelTab"
    private var cancellables: Set<AnyCancellable> = []

    init(library: MemeLibrary, usage: UsageStore, giphy: GiphyClient, defaults: UserDefaults = .standard) {
        self.library = library
        self.usage = usage
        self.giphy = giphy
        self.defaults = defaults
        tab = defaults.string(forKey: Self.tabKey).flatMap(MemeTab.init(rawValue:)) ?? .all
        // The publishers fire before the new value is stored; refresh on the next turn.
        library.$memes.dropFirst().map { _ in () }
            .merge(with: usage.$favourites.dropFirst().map { _ in () })
            .sink { [weak self] _ in Task { @MainActor in self?.refresh(keepSelection: true) } }
            .store(in: &cancellables)
        // Turning GIPHY on or off, or a new key, takes effect at once.
        AppSettings.shared.$searchGiphy.dropFirst().map { _ in () }
            .merge(with: AppSettings.shared.$giphyAPIKey.dropFirst().map { _ in () })
            .sink { [weak self] _ in Task { @MainActor in self?.refreshWeb(force: true) } }
            .store(in: &cancellables)
        refresh()
    }

    /// Local results and GIPHY results together: what the grid shows.
    var itemCount: Int { results.count + webResults.count }

    /// The GIPHY result under the selection, when it is past the local results.
    var selectedWebResult: Giphy.Result? {
        let index = selection - results.count
        return webResults.indices.contains(index) ? webResults[index] : nil
    }

    var selectedMeme: Meme? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    /// Moves the selection in the grid. Returns false when there is nothing to select.
    @discardableResult
    func move(_ direction: GridDirection) -> Bool {
        guard itemCount > 0 else { return false }
        selection = GridNavigation.move(direction, from: selection, count: itemCount, columns: Self.columns)
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

    /// Tab and ⇧Tab: the next or previous tab.
    func cycleTab(backwards: Bool) {
        tab = tab.next(backwards: backwards)
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
        openCount += 1
    }

    /// Recomputes the results from the memes of the current tab: favourites
    /// and recents first while the query is empty, best fuzzy matches otherwise.
    private func refresh(keepSelection: Bool = false) {
        defer { refreshWeb() }
        let selected = selectedMeme
        let egg = query.isEmpty && konamiActive ? EasterEggs.konami : EasterEggs.match(query)
        if easterEgg != egg { easterEgg = egg }
        let memes = tab.filter(library.memes)
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
        if let pendingReveal, let meme = library.memes.first(where: { $0.url.standardizedFileURL == pendingReveal }) {
            if !tab.contains(meme) {
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
        } else if egg?.effect == .randomPick, !results.isEmpty {
            selection = Int.random(in: results.indices)
        } else {
            selection = 0
        }
    }

    /// Asks GIPHY again when the tab or the query changed: trending for an
    /// empty query, a search otherwise, debounced while typing. Nothing in
    /// the All tab, during an easter egg, or without a key.
    private func refreshWeb(force: Bool = false) {
        let query = query.trimmingCharacters(in: .whitespaces)
        let catalogue = easterEgg == nil && giphy.isEnabled ? Giphy.catalogue(for: tab) : nil
        let request = catalogue.map { "\($0.rawValue)|\(query)" }
        guard force || request != webRequest else { return }
        webRequest = request
        webTask?.cancel()
        if !webResults.isEmpty { webResults = [] }
        guard let catalogue else { return }
        webTask = Task { [weak self] in
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(350)) }
            guard !Task.isCancelled, let self else { return }
            let found = (try? await self.giphy.search(catalogue, query: query)) ?? []
            guard !Task.isCancelled else { return }
            self.webResults = found
        }
    }
}
