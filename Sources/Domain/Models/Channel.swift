import Foundation

/// A normalised live TV channel.
public struct Channel: Identifiable, Hashable, Codable, Sendable {
    public let id: CatalogID

    /// Clean display name, e.g. `"TV4"` (not `"SE | TV4 HD [1080p]"`).
    public let name: String

    /// Provider's category/group, mapped to a friendly bucket.
    public let category: String

    public let logoURL: URL?
    public let countryCode: String?
    public let audioLanguages: [Language]
    public let subtitleLanguages: [Language]
    public let quality: VideoQuality

    /// The playable stream. Resolved lazily at playback time for real providers;
    /// concrete here for the mock provider.
    public let streamURL: URL

    /// EPG channel identifier used to join against `EPGEvent`.
    public let epgID: String?

    /// Provider-assigned ordering hint, used as a stable tiebreaker.
    public let sortIndex: Int

    public init(
        id: CatalogID,
        name: String,
        category: String,
        logoURL: URL? = nil,
        countryCode: String? = nil,
        audioLanguages: [Language] = [],
        subtitleLanguages: [Language] = [],
        quality: VideoQuality = .unknown,
        streamURL: URL,
        epgID: String? = nil,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.logoURL = logoURL
        self.countryCode = countryCode
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.quality = quality
        self.streamURL = streamURL
        self.epgID = epgID
        self.sortIndex = sortIndex
    }
}
