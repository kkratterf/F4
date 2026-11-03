import AppKit
import F4Core

/// Talks to GIPHY for the panel's GIPHY row: search, previews, downloads.
///
/// It only runs while the user is in the GIFs or Stickers tab of the open
/// panel: never in the background and never at launch. Responses are kept
/// for ten minutes, so opening the panel again does not ask GIPHY again.
/// The API key is the user's own (Settings), else the one the release
/// build was given (`F4GiphyAPIKey` in Info.plist, from the `GIPHY_API_KEY`
/// secret). Without a key the row is simply not there.
@MainActor
final class GiphyClient {
    static let shared = GiphyClient()

    private let session: URLSession
    private var responses: [URL: (date: Date, results: [Giphy.Result])] = [:]
    private let previews = NSCache<NSURL, NSData>()
    private let settings: AppSettings

    init(settings: AppSettings = .shared) {
        self.settings = settings
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
        previews.totalCostLimit = 32 * 1024 * 1024
    }

    /// The key requests are made with, if there is one.
    var apiKey: String? {
        let own = settings.giphyAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !own.isEmpty { return own }
        let builtIn = (Bundle.main.object(forInfoDictionaryKey: "F4GiphyAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return builtIn?.isEmpty == false ? builtIn : nil
    }

    /// Whether this build has a key at all (Settings explains when it has not).
    var hasKey: Bool { apiKey != nil }

    /// Whether the panel shows the GIPHY row.
    var isEnabled: Bool { settings.searchGiphy && hasKey }

    /// Trending for an empty query, search results otherwise.
    func search(_ catalogue: Giphy.Catalogue, query: String) async throws -> [Giphy.Result] {
        guard let apiKey else { return [] }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let url = Giphy.requestURL(catalogue, query: query, apiKey: apiKey, language: language)
        if let cached = responses[url], cached.date.timeIntervalSinceNow > -600 {
            return cached.results
        }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let results = try Giphy.results(from: data, catalogue: catalogue)
        responses[url] = (Date(), results)
        return results
    }

    /// The bytes of a preview or still, from memory when possible.
    func previewData(_ url: URL) async -> Data? {
        if let cached = previews.object(forKey: url as NSURL) { return cached as Data }
        guard let fetched = try? await session.data(from: url) else { return nil }
        let (data, response) = fetched
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { return nil }
        previews.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }

    /// The full GIF, downloaded once into F4's cache folder, so it can be
    /// copied as a file (that keeps it animated) or pinned into the meme folder.
    func file(for result: Giphy.Result) async throws -> URL {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.kkratterf.f4", isDirectory: true)
            .appendingPathComponent("GIPHY", isDirectory: true)
        let file = folder.appendingPathComponent("\(result.catalogue.rawValue)-\(result.id).gif")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let (data, response) = try await session.data(from: result.fileURL)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        guard MemeImport.kind(sniffing: data) == .gif else { throw URLError(.cannotDecodeContentData) }
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        }.value
        return file
    }
}
