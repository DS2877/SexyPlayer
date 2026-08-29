import Foundation

/// The rows the Home screen can show, in display order. The user chooses which
/// are enabled during onboarding and in Settings.
public enum HomeRowKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case continueWatching
    case liveNow
    case tonight
    case recentlyAdded
    case inYourLanguages
    case withYourSubtitles
    case movies
    case series

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .continueWatching:  return "Continue Watching"
        case .liveNow:           return "Live Now"
        case .tonight:           return "Tonight"
        case .recentlyAdded:     return "Recently Added"
        case .inYourLanguages:   return "In Your Languages"
        case .withYourSubtitles: return "With Your Subtitles"
        case .movies:            return "Movies"
        case .series:            return "Series"
        }
    }

    public var explanation: String {
        switch self {
        case .continueWatching:  return "Pick up where you left off"
        case .liveNow:           return "What's on across your channels"
        case .tonight:           return "Upcoming programmes this evening"
        case .recentlyAdded:     return "The newest additions to your library"
        case .inYourLanguages:   return "Content in the languages you chose"
        case .withYourSubtitles: return "Titles subtitled in your language"
        case .movies:            return "A shelf of films"
        case .series:            return "A shelf of shows"
        }
    }

    public static let defaultEnabled: [HomeRowKind] = allCases
}

/// Everything the user has decided about how the app behaves. Persisted as JSON.
public struct UserPreferences: Codable, Sendable, Equatable {
    /// Languages the user cares about — used to prioritise content and power the
    /// "In Your Languages" row. Empty = no preference.
    public var preferredAudioLanguages: [Language]

    /// The user's subtitle language, if they rely on subtitles.
    public var preferredSubtitleLanguage: Language?

    /// Keep adult categories out of Home, browsing and search.
    public var hideAdultContent: Bool

    /// Which Home rows to show, in order.
    public var homeRows: [HomeRowKind]

    /// Default ordering for the browse grids.
    public var defaultSort: BrowseSort

    /// Autoplay the next episode of a series.
    public var autoPlayNextEpisode: Bool

    /// Set once the user has been through onboarding.
    public var hasOnboarded: Bool

    public init(
        preferredAudioLanguages: [Language] = [],
        preferredSubtitleLanguage: Language? = nil,
        hideAdultContent: Bool = true,
        homeRows: [HomeRowKind] = HomeRowKind.defaultEnabled,
        defaultSort: BrowseSort = .titleAscending,
        autoPlayNextEpisode: Bool = true,
        hasOnboarded: Bool = false
    ) {
        self.preferredAudioLanguages = preferredAudioLanguages
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.hideAdultContent = hideAdultContent
        self.homeRows = homeRows
        self.defaultSort = defaultSort
        self.autoPlayNextEpisode = autoPlayNextEpisode
        self.hasOnboarded = hasOnboarded
    }

    public func isRowEnabled(_ kind: HomeRowKind) -> Bool { homeRows.contains(kind) }
}
