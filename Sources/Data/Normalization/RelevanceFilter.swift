import Foundation

/// Decides whether a catalog item is relevant to the current audience.
///
/// A typical Xtream provider dumps tens of thousands of channels and VOD entries
/// from every region on earth. For a Nordic audience the overwhelming majority is
/// noise. This keeps items that are Nordic, English-language, or unmarked/generic
/// (24-7, Sport, PPV…) and drops the rest.
public enum RelevanceFilter {

    public static let nordic: Set<String> = ["SE", "NO", "DK", "FI", "IS"]
    public static let english: Set<String> = ["GB", "IE", "US", "CA", "AU", "NZ"]

    /// ISO country codes kept when the region limit is on. Everything with no
    /// detected country is also kept (generic / international feeds).
    public static let keptRegions: Set<String> = nordic.union(english)

    /// Sort rank for a country: 0 = the viewer's home country, 1 = other Nordic,
    /// 2 = English / generic, 3 = anything else. Lower sorts first.
    public static func priority(countryCode: String?, home: Set<String>) -> Int {
        guard let code = countryCode else { return 2 }
        if home.contains(code) { return 0 }
        if nordic.contains(code) { return 1 }
        if english.contains(code) { return 2 }
        return 3
    }

    /// The viewer's home country codes, from their chosen audio languages.
    /// Defaults to Sweden — the launch market.
    public static func homeRegions(for languages: [Language]) -> Set<String> {
        let map = ["sv": "SE", "no": "NO", "nb": "NO", "nn": "NO",
                   "da": "DK", "fi": "FI", "is": "IS", "en": "GB"]
        let codes = Set(languages.compactMap { map[$0.code] })
        return codes.isEmpty ? ["SE"] : codes
    }

    /// Foreign-language markers that show up in provider category / channel names
    /// even when no clean country token was parsed. Matched as whole words.
    private static let foreignMarkers: Set<String> = [
        "arab", "arabic", "mbc", "osn",
        "turk", "turkish", "turkce", "turkiye",
        "hindi", "tamil", "telugu", "punjabi", "desi", "bollywood", "india", "indian",
        "urdu", "pakistan", "bangla", "bengali", "afghan",
        "farsi", "persian", "iran", "kurd", "kurdi",
        "hebrew", "israel",
        "latino", "latinos", "espanol", "español", "spanish", "mexico", "mexican",
        "brasil", "brazil", "brazilian", "portugues", "português", "portuguese",
        "polski", "polska", "polish", "poland",
        "romania", "romanian", "roman",
        "bulgaria", "bulgarian",
        "greek", "greece", "hellas", "ellada",
        "russia", "russian", "russkie",
        "ukraine", "ukrainian",
        "albania", "albanian", "shqip", "shqiptar",
        "srbija", "serbia", "serbian", "hrvatska", "croatia", "bosna", "bosnia",
        "makedonija", "macedonia", "balkan", "exyu", "ex-yu", "ex yu",
        "czech", "cesky", "slovak", "slovakia", "magyar", "hungary", "hungarian",
        "nederland", "dutch", "holland", "netherlands", "vlaams",
        "deutsch", "germany", "german", "österreich",
        "france", "french", "francais", "français",
        "italia", "italian", "italiano",
        "china", "chinese", "mandarin", "cantonese", "japan", "japanese", "korea", "korean",
        "thai", "vietnam", "filipino", "pinoy", "indonesia", "malaysia",
        "africa", "nigeria", "nollywood", "ghana", "ethiopia", "amharic",
        "somali", "somalia", "swahili", "kenya",
    ]

    /// `true` when the item should stay in the catalog under the region limit.
    public static func isRelevant(countryCode: String?, name: String, category: String) -> Bool {
        if let code = countryCode {
            return keptRegions.contains(code)
        }
        // No parsed country — fall back to a whole-word scan of the strings the
        // provider gave us (handles stale caches and messy tags).
        let haystack = (name + " " + category).lowercased()
        for marker in foreignMarkers where haystack.range(of: "\\b" + NSRegularExpression.escapedPattern(for: marker) + "\\b",
                                                          options: .regularExpression) != nil {
            return false
        }
        return true
    }
}
