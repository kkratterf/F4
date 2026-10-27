import Foundation

/// GIPHY search, as F4 uses it: requests and the parts of the response the
/// panel needs. No networking here; the app sends the requests.
public enum Giphy {
    /// GIPHY's two catalogues, matching the panel's GIFs and Stickers tabs.
    public enum Catalogue: String, Sendable {
        case gifs
        case stickers
    }

    /// The catalogue a tab searches, or nil for a tab with no GIPHY row.
    public static func catalogue(for tab: MemeTab) -> Catalogue? {
        switch tab {
        case .all: return nil
        case .gifs: return .gifs
        case .stickers: return .stickers
        }
    }

    /// How many results the panel asks for: four rows of the grid.
    public static let pageSize = 20

    /// The request URL: trending for an empty query, search otherwise.
    /// Rated PG-13 at most, like GIPHY's own keyboard apps.
    public static func requestURL(
        _ catalogue: Catalogue,
        query: String,
        apiKey: String,
        limit: Int = pageSize,
        language: String = "en"
    ) -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.giphy.com"
        components.path = "/v1/\(catalogue.rawValue)/\(trimmed.isEmpty ? "trending" : "search")"
        var items = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "rating", value: "pg-13"),
        ]
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "q", value: String(trimmed.prefix(50))))
            items.append(URLQueryItem(name: "lang", value: language))
        }
        // URLComponents leaves "&", "=" and "+" alone in query values, which
        // would split a query like "salt & pepper"; encode them too.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?/")
        components.percentEncodedQueryItems = items.map {
            URLQueryItem(name: $0.name, value: $0.value?.addingPercentEncoding(withAllowedCharacters: allowed))
        }
        return components.url!
    }

    /// One GIF or sticker found on GIPHY.
    public struct Result: Identifiable, Hashable, Sendable {
        public let id: String
        public let catalogue: Catalogue
        /// GIPHY's title, e.g. "Happy Dance GIF by The Office".
        public let title: String
        /// The GIF's page on GIPHY (attribution, "Open on GIPHY").
        public let pageURL: URL?
        /// A small animated GIF for the grid cell.
        public let previewURL: URL
        /// A still of the same size, shown until the cell is hovered or selected.
        public let stillURL: URL?
        /// The file that is copied or pinned.
        public let fileURL: URL

        public init(id: String, catalogue: Catalogue, title: String, pageURL: URL?, previewURL: URL, stillURL: URL?, fileURL: URL) {
            self.id = id
            self.catalogue = catalogue
            self.title = title
            self.pageURL = pageURL
            self.previewURL = previewURL
            self.stillURL = stillURL
            self.fileURL = fileURL
        }

        /// A file name for a pinned result: the title without GIPHY's
        /// " GIF by …" / " Sticker by …" tail ("happy dance").
        public var name: String {
            var name = title
            for marker in [" GIF by ", " Sticker by ", " GIF", " Sticker"] {
                if let range = name.range(of: marker, options: [.caseInsensitive, .backwards]) {
                    name = String(name[..<range.lowerBound])
                    break
                }
            }
            name = name.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? "giphy \(id)" : name
        }
    }

    /// The results in a GIPHY response; items without usable images are skipped.
    public static func results(from data: Data, catalogue: Catalogue) throws -> [Result] {
        try JSONDecoder().decode(Response.self, from: data).data.compactMap { item in
            let images = item.images
            guard let preview = (images["fixed_width_small"] ?? images["fixed_width"])?.url.flatMap({ URL(string: $0) }),
                  let file = (images["original"] ?? images["downsized"])?.url.flatMap({ URL(string: $0) })
            else { return nil }
            let still = (images["fixed_width_small_still"] ?? images["fixed_width_still"])?.url.flatMap({ URL(string: $0) })
            return Result(
                id: item.id,
                catalogue: catalogue,
                title: item.title ?? "",
                pageURL: item.url.flatMap({ URL(string: $0) }),
                previewURL: preview,
                stillURL: still,
                fileURL: file
            )
        }
    }

    private struct Response: Decodable {
        let data: [Item]
    }

    private struct Item: Decodable {
        let id: String
        let title: String?
        let url: String?
        let images: [String: Image]
    }

    private struct Image: Decodable {
        let url: String?
    }
}
