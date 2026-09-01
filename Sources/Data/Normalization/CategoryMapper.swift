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
        let tidied = (groupTitle ?? "")
            .replacingOccurrences(of: "|", with: " ")
            .collapsingWhitespace()
        return tidied.isEmpty ? "General" : tidied
    }

    private static let countryTokens: [String: String] = [
        // Nordics
        "se": "SE", "sv": "SE", "swe": "SE", "sweden": "SE", "sverige": "SE", "swedish": "SE",
        "no": "NO", "nor": "NO", "norway": "NO", "norge": "NO", "norwegian": "NO",
        "dk": "DK", "da": "DK", "dan": "DK", "denmark": "DK", "danmark": "DK", "danish": "DK",
        "fi": "FI", "fin": "FI", "finland": "FI", "suomi": "FI", "finnish": "FI",
        "is": "IS", "isl": "IS", "iceland": "IS", "island": "IS",
        // English-speaking
        "uk": "GB", "gb": "GB", "eng": "GB", "england": "GB", "britain": "GB", "british": "GB", "ireland": "IE", "irish": "IE", "ie": "IE",
        "us": "US", "usa": "US", "america": "US", "american": "US",
        "ca": "CA", "canada": "CA", "au": "AU", "aus": "AU", "australia": "AU", "nz": "NZ",
        // Rest of Europe
        "de": "DE", "ger": "DE", "germany": "DE", "deutsch": "DE", "german": "DE",
        "fr": "FR", "fra": "FR", "france": "FR", "french": "FR",
        "es": "ES", "esp": "ES", "spain": "ES", "spanish": "ES", "espana": "ES", "españa": "ES",
        "it": "IT", "ita": "IT", "italy": "IT", "italia": "IT", "italian": "IT",
        "pt": "PT", "por": "PT", "portugal": "PT", "portuguese": "PT",
        "nl": "NL", "dutch": "NL", "holland": "NL", "netherlands": "NL",
        "pl": "PL", "pol": "PL", "poland": "PL", "polska": "PL", "polish": "PL",
        "ro": "RO", "rom": "RO", "romania": "RO", "romanian": "RO",
        "bg": "BG", "bul": "BG", "bulgaria": "BG", "bulgarian": "BG",
        "gr": "GR", "gre": "GR", "greece": "GR", "greek": "GR", "hellas": "GR",
        "ru": "RU", "rus": "RU", "russia": "RU", "russian": "RU",
        "ua": "UA", "ukr": "UA", "ukraine": "UA",
        "cz": "CZ", "czech": "CZ", "sk": "SK", "slovak": "SK", "slovakia": "SK",
        "hu": "HU", "hun": "HU", "hungary": "HU", "hungarian": "HU",
        "at": "AT", "austria": "AT", "ch": "CH", "swiss": "CH",
        "be": "BE", "belgium": "BE", "belgique": "BE",
        "hr": "HR", "croatia": "HR", "hrv": "HR", "srb": "RS", "serbia": "RS", "rs": "RS",
        "bih": "BA", "bosnia": "BA", "mk": "MK", "macedonia": "MK", "si": "SI", "slovenia": "SI",
        "al": "AL", "alb": "AL", "albania": "AL", "kosovo": "XK", "exyu": "RS", "balkan": "RS", "ex-yu": "RS",
        "tr": "TR", "turk": "TR", "turkey": "TR", "turkish": "TR", "türk": "TR", "türkiye": "TR",
        // MENA / Asia / Africa / LatAm — the bulk of a typical Xtream dump
        "ar": "SA", "arab": "SA", "arabic": "SA", "mbc": "SA", "osn": "SA",
        "il": "IL", "israel": "IL", "hebrew": "IL", "ir": "IR", "iran": "IR", "farsi": "IR", "persian": "IR",
        "in": "IN", "ind": "IN", "india": "IN", "hindi": "IN", "tamil": "IN", "telugu": "IN", "punjabi": "IN", "desi": "IN",
        "pk": "PK", "pakistan": "PK", "urdu": "PK", "bd": "BD", "bangla": "BD", "bangladesh": "BD",
        "af": "AF", "afghan": "AF", "afghanistan": "AF",
        "cn": "CN", "china": "CN", "chinese": "CN", "jp": "JP", "japan": "JP", "kr": "KR", "korea": "KR", "korean": "KR",
        "ph": "PH", "philippines": "PH", "filipino": "PH", "th": "TH", "thai": "TH", "vn": "VN", "vietnam": "VN",
        "id": "ID", "indonesia": "ID", "my": "MY", "malaysia": "MY",
        "mx": "MX", "mexico": "MX", "latino": "MX", "latin": "MX", "br": "BR", "brazil": "BR", "brasil": "BR",
        "ar-lat": "AR", "argentina": "AR", "co": "CO", "colombia": "CO", "cl": "CL", "chile": "CL", "pe": "PE", "peru": "PE",
        "africa": "NG", "nigeria": "NG", "ng": "NG", "gh": "GH", "ghana": "GH", "et": "ET", "ethiopia": "ET",
        "so": "SO", "somalia": "SO", "somali": "SO", "ke": "KE", "kenya": "KE", "za": "ZA",
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
