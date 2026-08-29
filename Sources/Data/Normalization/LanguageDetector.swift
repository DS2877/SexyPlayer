import Foundation

/// Infers audio and subtitle languages from raw names, group titles and tags.
///
/// IPTV data expresses this a dozen ways:
///   "EN | Movie (SweSub)", "Movie [Nordic]", "SE: Movie", "Movie - SUB SV"
public enum LanguageDetector {

    // country/language token -> language
    private static let tokenMap: [String: Language] = [
        "en": .english, "eng": .english, "english": .english, "uk": .english,
        "us": .english, "gb": .english,
        "sv": .swedish, "swe": .swedish, "swedish": .swedish, "se": .swedish,
        "sweden": .swedish,
        "no": .norwegian, "nor": .norwegian, "norwegian": .norwegian,
        "nb": .norwegian,
        "da": .danish, "dan": .danish, "danish": .danish, "dk": .danish,
        "fi": .finnish, "fin": .finnish, "finnish": .finnish,
        "de": .german, "ger": .german, "german": .german, "deu": .german,
        "es": .spanish, "spa": .spanish, "spanish": .spanish,
        "fr": .french, "fra": .french, "french": .french, "fre": .french,
    ]

    /// e.g. "swesub", "engsub", "nosub", "swe sub", "sub swe"
    private static let subtitleToken = CompiledPattern(
        #"(?:(swe|sve|sv|eng|en|nor|no|dan|da|fin|fi|ger|de|spa|es|fra|fr)[\s\-]?sub|sub[\s\-]?(swe|sve|sv|eng|en|nor|no|dan|da|fin|fi|ger|de|spa|es|fra|fr))"#
    )
    private static let subShort = [
        "swe": Language.swedish, "sve": .swedish, "sv": .swedish,
        "eng": .english, "en": .english,
        "nor": .norwegian, "no": .norwegian,
        "dan": .danish, "da": .danish,
        "fin": .finnish, "fi": .finnish,
        "ger": .german, "de": .german,
        "spa": .spanish, "es": .spanish,
        "fra": .french, "fr": .french,
    ]

    /// A bare 2–3 letter language code inside brackets/parens: "[EN]", "(SWE)".
    private static let bracketedCode = CompiledPattern(#"[\[\(]([a-z]{2,3})[\]\)]"#)

    /// A leading code acting as a tag: "SE | ...", "UK: ...", "EN - ...".
    private static let leadingTag = CompiledPattern(#"^\s*[\[\(]?([a-z]{2,3})[\]\)]?\s*[:|\-–—]"#)

    private static let nordicToken = CompiledPattern(#"(?<![a-z])(nordic|scandinavian|norden)(?![a-z])"#)
    private static let multiSubToken = CompiledPattern(#"(?<![a-z])(multi\s?sub|multisub|msub)(?![a-z])"#)

    public struct Result: Equatable, Sendable {
        public var audio: [Language]
        public var subtitles: [Language]
    }

    public static func detect(name: String, groupTitle: String? = nil, tags: [String] = []) -> Result {
        let haystacks = ([name, groupTitle ?? ""] + tags).map { $0.lowercased() }
        let joined = haystacks.joined(separator: " | ")

        var subtitles = Set<Language>()
        var audio = Set<Language>()

        // Explicit subtitle markers.
        if let groups = subtitleToken.firstMatchGroups(joined) {
            for candidate in groups.dropFirst().compactMap({ $0?.lowercased() }) {
                if let lang = subShort[candidate] { subtitles.insert(lang) }
            }
        }
        if nordicToken.matches(joined) {
            subtitles.formUnion([.swedish, .norwegian, .danish, .finnish])
        }
        if multiSubToken.matches(joined) {
            subtitles.formUnion([.english, .swedish])
        }

        // A leading language/country code that is clearly a *tag* — followed by
        // a tag delimiter (| : -), not a plain space. This avoids reading the
        // Swedish word "En" in "En man som heter Ove" as English.
        if let groups = leadingTag.firstMatchGroups(name.lowercased()),
           let code = groups.dropFirst().compactMap({ $0 }).first,
           let lang = tokenMap[code] {
            audio.insert(lang)
        }
        // Bracketed short language codes anywhere: "[EN]", "(SWE)", "[de]"
        if let groups = bracketedCode.firstMatchGroups(name.lowercased()) {
            for candidate in groups.dropFirst().compactMap({ $0 }) {
                if let lang = tokenMap[candidate] { audio.insert(lang) }
            }
        }
        // Group titles frequently name the audio language: "Movies | Swedish"
        for token in wordTokens(in: groupTitle ?? "") {
            if let lang = tokenMap[token], token.count > 2 { audio.insert(lang) }
        }

        return Result(
            audio: audio.sorted(),
            subtitles: subtitles.sorted()
        )
    }

    // MARK: - Tokenisation helpers

    private static let delimiters = CharacterSet(charactersIn: " |:-–—/[](){}.,")

    private static func wordTokens(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: delimiters)
            .filter { !$0.isEmpty }
    }
}

extension LanguageDetector.Result {
    public static let empty = LanguageDetector.Result(audio: [], subtitles: [])
}
