import Foundation

/// Remote query parser backed by Anthropic's Messages API. Used only for the
/// vague "something like X" queries the on-device parser can't resolve.
///
/// Privacy: the request body contains **only** the raw query string and the
/// library-derived `SearchVocabulary` (genre / language lists). No titles,
/// provider credentials, stream URLs, watch history, or device identifiers are
/// ever sent. The key lives in the Keychain and is sent only to api.anthropic.com.
public struct ClaudeQueryParser: AIQueryParser {

    private let apiKey: String
    private let session: URLSession
    private let model = "claude-haiku-4-5-20251001"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func parse(_ query: String, vocabulary: SearchVocabulary) async throws -> SearchIntent {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIQueryParserError.empty }
        guard !apiKey.isEmpty else { throw AIQueryParserError.providerUnavailable }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: model,
            max_tokens: 400,
            system: Self.systemPrompt(vocabulary),
            messages: [Message(role: "user", content: trimmed)]
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw AIQueryParserError.providerUnavailable
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIQueryParserError.malformedResponse
        }
        return try Self.intent(fromModelText: text, vocabulary: vocabulary)
    }

    // MARK: - Request / response shapes

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
    }
    private struct Message: Encodable { let role: String; let content: String }

    private struct APIResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private struct ParsedIntent: Decodable {
        var kinds: [String]?
        var genres: [String]?
        var audioLanguages: [String]?
        var subtitleLanguages: [String]?
        var minYear: Int?
        var maxYear: Int?
        var maxDurationMinutes: Int?
        var minQuality: String?
        var freeText: String?
        var timeContext: String?
    }

    // MARK: - Prompt + mapping

    static func systemPrompt(_ vocab: SearchVocabulary) -> String {
        let genres = vocab.genres.map(\.rawValue).joined(separator: ", ")
        let audio = vocab.audioLanguages.map(\.code).joined(separator: ", ")
        let subs = vocab.subtitleLanguages.map(\.code).joined(separator: ", ")
        return """
        You convert a natural-language request for something to watch into a strict JSON filter. \
        Respond with a single JSON object and nothing else — no prose, no code fences.

        Schema (omit any field you cannot infer):
        {
          "kinds": ["movie" | "series" | "liveChannel"],
          "genres": [string],           // only from: \(genres.isEmpty ? "(none)" : genres)
          "audioLanguages": [string],   // ISO 639-1, only from: \(audio.isEmpty ? "(none)" : audio)
          "subtitleLanguages": [string],// ISO 639-1, only from: \(subs.isEmpty ? "(none)" : subs)
          "minYear": int, "maxYear": int,
          "maxDurationMinutes": int,
          "minQuality": "sd" | "hd" | "fhd" | "uhd",
          "timeContext": "now" | "tonight",
          "freeText": string            // remaining keywords, e.g. a title or actor
        }

        Rules: use ONLY the exact tokens listed. If a genre/language isn't listed, put the word in freeText. \
        "scary" -> horror, "funny" -> comedy, "4k" -> minQuality uhd, "short" -> maxDurationMinutes 90.
        """
    }

    static func intent(fromModelText raw: String, vocabulary: SearchVocabulary) throws -> SearchIntent {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              let data = String(cleaned[start ... end]).data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ParsedIntent.self, from: data)
        else { throw AIQueryParserError.malformedResponse }

        let allowedGenres = Set(vocabulary.genres)
        let allowedAudio = Set(vocabulary.audioLanguages)
        let allowedSubs = Set(vocabulary.subtitleLanguages)

        var intent = SearchIntent()
        intent.kinds = (parsed.kinds ?? []).compactMap(ContentKind.init(rawValue:))
        intent.genres = (parsed.genres ?? []).compactMap { Genre(rawValue: $0) }.filter { allowedGenres.contains($0) || allowedGenres.isEmpty }
        intent.audioLanguages = (parsed.audioLanguages ?? []).compactMap { Language(code: $0) }.filter { allowedAudio.contains($0) || allowedAudio.isEmpty }
        intent.subtitleLanguages = (parsed.subtitleLanguages ?? []).compactMap { Language(code: $0) }.filter { allowedSubs.contains($0) || allowedSubs.isEmpty }
        intent.minYear = parsed.minYear
        intent.maxYear = parsed.maxYear
        intent.maxDurationMinutes = parsed.maxDurationMinutes
        intent.minQuality = parsed.minQuality.flatMap { VideoQuality(rawValue: $0) }
        intent.timeContext = parsed.timeContext.flatMap { SearchIntent.TimeContext(rawValue: $0) }
        intent.freeText = (parsed.freeText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return intent
    }
}
