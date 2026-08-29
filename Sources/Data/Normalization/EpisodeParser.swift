import Foundation

/// Pulls season/episode numbers and a clean series title out of a raw episode
/// name. Handles the common IPTV spellings:
///
///   "The Last of Us S01E03"
///   "The Last of Us - S1 E3"
///   "The Last of Us 1x03"
///   "The Last of Us Season 1 Episode 3"
///   "The.Last.of.Us.S01E03.1080p"
public enum EpisodeParser {

    public struct Parsed: Equatable, Sendable {
        public let seriesTitle: String
        public let season: Int
        public let episode: Int
    }

    private static let patterns: [CompiledPattern] = [
        CompiledPattern(#"^(.*?)[\s\-_.]*s(\d{1,2})[\s\-_.]*e(\d{1,4})(?!\d)"#),
        CompiledPattern(#"^(.*?)[\s\-_.]*(\d{1,2})x(\d{1,4})(?![a-z0-9])"#),
        CompiledPattern(#"^(.*?)[\s\-_.]*season[\s\-_.]*(\d{1,2})[\s\-_.]*episode[\s\-_.]*(\d{1,4})(?!\d)"#),
    ]

    public static func parse(_ raw: String) -> Parsed? {
        let input = raw.collapsingWhitespace()
        for pattern in patterns {
            guard let groups = pattern.firstMatchGroups(input),
                  groups.count >= 4,
                  let rawTitle = groups[1],
                  let seasonStr = groups[2], let season = Int(seasonStr),
                  let episodeStr = groups[3], let episode = Int(episodeStr)
            else { continue }

            let title = cleanTitle(rawTitle)
            guard !title.isEmpty else { continue }
            return Parsed(seriesTitle: title, season: season, episode: episode)
        }
        return nil
    }

    private static func cleanTitle(_ raw: String) -> String {
        var t = raw.replacingOccurrences(of: ".", with: " ")
        t = t.replacingOccurrences(of: "_", with: " ")
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " -–—:|"))
        return t.collapsingWhitespace()
    }
}
