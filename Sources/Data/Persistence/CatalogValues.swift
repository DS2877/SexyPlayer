import Foundation

/// Encoders / decoders between domain value types and their scalar column
/// representations. One place so the writer and the reader always agree.
///
/// Genre and language lists are stored **comma-delimited with leading and
/// trailing commas** (`",en,sv,"`, empty → `""`). That lets a query test
/// membership with `instr(col, ',en,') > 0` and never get a partial-code false
/// match.
enum CatalogValues {

    // MARK: Genres

    static func encode(_ genres: [Genre]) -> String {
        wrap(genres.map(\.rawValue))
    }

    static func decodeGenres(_ raw: String) -> [Genre] {
        unwrap(raw).compactMap(Genre.init(rawValue:))
    }

    /// The `instr` needle for "has this genre" — `",action,"`.
    static func needle(_ genre: Genre) -> String { ",\(genre.rawValue)," }

    // MARK: Languages

    static func encode(_ languages: [Language]) -> String {
        wrap(languages.map(\.code))
    }

    static func decodeLanguages(_ raw: String) -> [Language] {
        unwrap(raw).compactMap { Language(code: $0) }
    }

    static func needle(_ language: Language) -> String { ",\(language.code)," }

    // MARK: Quality

    static func encode(_ quality: VideoQuality) -> String { quality.rawValue }

    static func decodeQuality(_ raw: String) -> VideoQuality {
        VideoQuality(rawValue: raw) ?? .unknown
    }

    // MARK: Name lists (cast, directors) — newline-joined, no wrapping

    static func encode(list: [String]) -> String {
        list.map { $0.replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\n")
    }

    static func decodeList(_ raw: String) -> [String] {
        raw.split(separator: "\n").map(String.init)
    }

    // MARK: -

    private static func wrap(_ items: [String]) -> String {
        let clean = items.filter { !$0.isEmpty }
        return clean.isEmpty ? "" : "," + clean.joined(separator: ",") + ","
    }

    private static func unwrap(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init)
    }
}
