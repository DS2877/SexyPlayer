import Foundation

/// Decides whether a catalog item is relevant to the current audience.
///
/// A typical Xtream provider dumps tens of thousands of channels and VOD entries
/// from every region on earth. The focus here is **Sweden and Europe**, so this
/// keeps items that are Nordic, European or English-language — plus anything the
/// viewer could actually watch (English or Nordic audio *or* subtitles) wherever
/// it's from — and drops the rest (Arabic, African, Russian, South/East-Asian,
/// Latin-American …).
public enum RelevanceFilter {

    public static let nordic: Set<String> = ["SE", "NO", "DK", "FI", "IS"]
    public static let english: Set<String> = ["GB", "IE", "US", "CA", "AU", "NZ"]

    /// Continental Europe kept under the region limit. Russia and Belarus are
    /// deliberately excluded; Turkey is treated as non-European here (the focus
    /// is the EU / EEA).
    public static let europe: Set<String> = [
        "DE", "FR", "ES", "IT", "PT", "NL", "BE", "AT", "CH", "LU",
        "PL", "CZ", "SK", "HU", "RO", "BG", "GR", "HR", "SI", "RS",
        "BA", "MK", "AL", "XK", "ME", "EE", "LV", "LT", "UA",
        "MT", "CY",
    ]

    /// ISO country codes kept when the region limit is on. Everything with no
    /// detected country is also kept unless a foreign marker is found in its
    /// name / category (generic / international feeds).
    public static let keptRegions: Set<String> = nordic.union(english).union(europe)

    /// Audio / subtitle language codes that keep an item no matter where it's
    /// from — the viewer can hear it or read it. ("…unless it has english or
    /// swedish speak and text.")
    static let watchableLanguageCodes: Set<String> = ["en", "sv", "no", "nb", "nn", "da", "fi", "is"]

    /// Sort rank for a country: 0 = the viewer's home country, 1 = other Nordic,
    /// 2 = English / European / generic, 3 = anything else. Lower sorts first.
    public static func priority(countryCode: String?, home: Set<String>) -> Int {
        guard let code = countryCode else { return 2 }
        if home.contains(code) { return 0 }
        if nordic.contains(code) { return 1 }
        if english.contains(code) || europe.contains(code) { return 2 }
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

    /// Single-word foreign-region markers that show up in provider category /
    /// channel names even when no clean country token was parsed. Matched as
    /// whole words (tokenised, not substring). European markers are intentionally
    /// absent — Europe is kept.
    private static let foreignMarkers: Set<String> = [
        "arab", "arabic", "mbc", "osn", "rotana",
        "turk", "turkish", "turkce", "turkiye",
        "hindi", "tamil", "telugu", "punjabi", "desi", "bollywood", "india", "indian",
        "urdu", "pakistan", "bangla", "bengali", "afghan",
        "farsi", "persian", "iran", "kurd", "kurdi", "kurdish",
        "hebrew", "israel", "israeli",
        "latino", "latinos", "latin", "mexico", "mexican",
        "brasil", "brazil", "brazilian",
        "russia", "russian", "russkie", "rossiya",
        "belarus",
        "china", "chinese", "mandarin", "cantonese",
        "japan", "japanese", "korea", "korean",
        "thai", "vietnam", "vietnamese", "filipino", "pinoy", "indonesia", "malaysia", "khmer",
        "africa", "african", "nigeria", "nollywood", "ghana", "ethiopia", "amharic",
        "somali", "somalia", "swahili", "kenya", "uganda", "tanzania",
    ]

    /// Hyphenated / spaced markers that whole-word tokenising splits apart.
    private static let foreignPhrases: [String] = ["ex-yu", "ex yu", "exyu"]

    /// `true` when the item should stay in the catalog under the region limit.
    public static func isRelevant(
        countryCode: String?,
        name: String,
        category: String,
        audioLanguages: [Language] = [],
        subtitleLanguages: [Language] = []
    ) -> Bool {
        // The escape hatch: English or Nordic audio *or* subtitles keeps it,
        // wherever it's from.
        let langCodes = Set((audioLanguages + subtitleLanguages).map(\.code))
        if !langCodes.isDisjoint(with: watchableLanguageCodes) { return true }

        if let code = countryCode {
            return keptRegions.contains(code)
        }

        // No parsed country — a whole-word scan of the strings the provider gave
        // us (handles stale caches and messy tags). Tokenise once, then a single
        // set-disjoint test instead of ~80 regex passes per row.
        let lowered = (name + " " + category).lowercased()
        let tokens = Set(lowered.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if !foreignMarkers.isDisjoint(with: tokens) { return false }
        if foreignPhrases.contains(where: { lowered.contains($0) }) { return false }
        return true
    }
}
