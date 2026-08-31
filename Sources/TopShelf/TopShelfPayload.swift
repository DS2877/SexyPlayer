import Foundation

/// The small hand-off the app writes to the shared App Group container and the
/// Top Shelf extension reads. Deliberately self-contained — no app types — so
/// the extension stays tiny.
public struct TopShelfPayload: Codable, Sendable, Equatable {

    public struct Item: Codable, Sendable, Equatable {
        public let title: String
        public let subtitle: String?
        public let imageURL: URL?
        /// "movie" | "series" | "channel"
        public let routeKind: String
        /// `CatalogID.rawValue`
        public let id: String

        public init(title: String, subtitle: String?, imageURL: URL?, routeKind: String, id: String) {
            self.title = title
            self.subtitle = subtitle
            self.imageURL = imageURL
            self.routeKind = routeKind
            self.id = id
        }

        /// `aeria://movie/<percent-encoded id>` — opened via `AeriaApp.onOpenURL`.
        public var deepLink: URL? {
            let encoded = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id
            return URL(string: "aeria://\(routeKind)/\(encoded)")
        }
    }

    public let continueWatching: [Item]
    public let recentlyAdded: [Item]
    public let generatedAt: Date

    public init(continueWatching: [Item], recentlyAdded: [Item], generatedAt: Date = .init()) {
        self.continueWatching = continueWatching
        self.recentlyAdded = recentlyAdded
        self.generatedAt = generatedAt
    }
}

/// Reads / writes `TopShelfPayload` in the shared App Group container.
public enum TopShelfStore {
    public static let appGroupID = "group.com.aeriaplus.appletv"
    private static let filename = "topshelf.v1.json"

    public static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(filename)
    }

    public static func load() -> TopShelfPayload? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.topShelf.decode(TopShelfPayload.self, from: data)
    }

    public static func save(_ payload: TopShelfPayload) {
        guard let url = fileURL, let data = try? JSONEncoder.topShelf.encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private extension JSONEncoder {
    static let topShelf: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
}
private extension JSONDecoder {
    static let topShelf: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
