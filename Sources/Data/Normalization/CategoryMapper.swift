import Foundation

/// Maps messy provider group titles onto a small set of friendly buckets, and
/// pulls a country code out of names/groups when one is clearly present.
public enum CategoryMapper {

    private static let buckets: [(String, [String])] = [
        ("News",          ["news", "nyheter"]),
        ("Sports",        ["sport", "sports", "espn", "sky sport", "dazn", "viaplay sport"]),
        ("Movies",        ["movie", "movies", "cinema", "film", "filmer"]),
        ("Kids",          ["kids", "barn", "children", "cartoon", "disney"]),
        ("Documentary",   ["doc", "docu", "documentary", "discovery", "history", "nat geo"]),
        ("Entertainment", ["entertainment", "general", "underhållning"]),
        ("Music",         ["music", "musik", "mtv", "vevo"]),
        ("Lifestyle",     ["lifestyle", "food", "cooking", "home", "travel"]),
    ]

    public static func channelCategory(from groupTitle: String?) -> String {
        guard let g = groupTitle?.lowercased(), !g.isEmpty else { return "General" }
        for (bucket, terms) in buckets where terms.contains(where: { g.contains($0) }) {
            return bucket
        }
        // Fall back to a tidied version of the provider's own group.
        let tidied = groupTitle!
            .replacingOccurrences(of: "|", with: " ")
            .collapsingWhitespace()
        return tidied.isEmpty ? "General" : tidied
    }

    private static let countryTokens: [String: String] = [
        "se": "SE", "swe": "SE", "sweden": "SE", "sverige": "SE",
        "no": "NO", "nor": "NO", "norway": "NO", "norge": "NO",
        "dk": "DK", "dan": "DK", "denmark": "DK", "danmark": "DK",
        "fi": "FI", "fin": "FI", "finland": "FI", "suomi": "FI",
        "uk": "GB", "gb": "GB", "england": "GB",
        "us": "US", "usa": "US",
        "de": "DE", "ger": "DE", "germany": "DE",
    ]

    public static func countryCode(from name: String, groupTitle: String?) -> String? {
        let delimiters = CharacterSet(charactersIn: " |:-–—/[](){}.,")
        let tokens = ([name, groupTitle ?? ""])
            .joined(separator: " ")
            .lowercased()
            .components(separatedBy: delimiters)
            .filter { !$0.isEmpty }

        // Prefer a token that appears in the first three positions (leading tag).
        for token in tokens.prefix(3) {
            if let code = countryTokens[token] { return code }
        }
        for token in tokens {
            if token.count > 2, let code = countryTokens[token] { return code }
        }
        return nil
    }
}
