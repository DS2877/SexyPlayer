import Foundation

/// Maps free-form genre text and group titles onto the closed `Genre` set.
public enum GenreDetector {

    private static let keywords: [(Genre, [String])] = [
        (.action,      ["action", "martial arts"]),
        (.adventure,   ["adventure"]),
        (.animation,   ["animation", "animated", "anime", "cartoon"]),
        (.comedy,      ["comedy", "comedies", "sitcom", "stand-up", "standup"]),
        (.crime,       ["crime", "heist", "mafia", "gangster"]),
        (.documentary, ["documentary", "documentaries", "docu", "nature"]),
        (.drama,       ["drama"]),
        (.family,      ["family"]),
        (.fantasy,     ["fantasy", "magic", "medieval"]),
        (.history,     ["history", "historical", "period"]),
        (.horror,      ["horror", "slasher", "scary", "zombie", "haunted"]),
        (.music,       ["music", "musical", "concert"]),
        (.mystery,     ["mystery", "whodunit"]),
        (.romance,     ["romance", "romantic", "rom-com", "rom com"]),
        (.sciFi,       ["sci-fi", "sci fi", "science fiction", "scifi", "space"]),
        (.thriller,    ["thriller", "suspense"]),
        (.war,         ["war", "military"]),
        (.western,     ["western"]),
        (.kids,        ["kids", "children", "child", "junior"]),
        (.news,        ["news"]),
        (.sport,       ["sport", "sports", "football", "soccer", "nba", "nfl", "ufc", "boxing"]),
        (.reality,     ["reality", "lifestyle", "cooking"]),
    ]

    public static func detect(from candidates: [String?]) -> [Genre] {
        let haystack = candidates.compactMap { $0?.lowercased() }.joined(separator: " | ")
        guard !haystack.isEmpty else { return [] }

        var found: [Genre] = []
        for (genre, terms) in keywords where terms.contains(where: { haystack.contains($0) }) {
            found.append(genre)
        }
        return found
    }
}
