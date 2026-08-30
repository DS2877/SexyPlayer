import Foundation

/// The single boundary between the app and any AI capability.
///
/// Privacy contract (enforced here, documented for users in Settings):
///   • Sent:     the raw query string, plus a compact `SearchVocabulary`
///               (available genres / languages / content kinds).
///   • Never sent: provider credentials, stream URLs, catalog contents,
///               titles, watch history, or any device identifier.
///
/// When AI is disabled, or the remote parser fails, everything falls back to the
/// on-device `DeterministicQueryParser`.
public actor AIService {

    public enum Mode: String, Sendable, CaseIterable {
        /// On-device only. Nothing leaves the device.
        case onDeviceOnly
        /// Use the remote parser for queries the on-device parser can't resolve,
        /// falling back to on-device on any error.
        case assisted
    }

    private let deterministic: DeterministicQueryParser
    private var remote: AIQueryParser?
    public private(set) var mode: Mode

    public init(
        deterministic: DeterministicQueryParser = DeterministicQueryParser(),
        remote: AIQueryParser? = nil,
        mode: Mode = .onDeviceOnly
    ) {
        self.deterministic = deterministic
        self.remote = remote
        self.mode = mode
    }

    public func setMode(_ newMode: Mode) {
        mode = newMode
    }

    /// Install (or clear) the remote parser — called when the user adds/removes
    /// an API key. `nil` means assisted mode silently stays on-device.
    public func setRemoteParser(_ parser: AIQueryParser?) {
        remote = parser
    }

    /// True when a remote parser is available (a key is configured).
    public var hasRemoteParser: Bool { remote != nil }

    /// Parse a query into a `SearchIntent`. Always returns something usable.
    public func intent(for query: String, vocabulary: SearchVocabulary) async -> SearchIntent {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let localIntent = deterministic.parseSync(trimmed, vocabulary: vocabulary)

        guard mode == .assisted, let remote else { return localIntent }

        // Only escalate when the on-device parser produced little structure but
        // there is meaningful free text left (the "something like X" case).
        let looksUnresolved = localIntent.genres.isEmpty
            && localIntent.kinds.isEmpty
            && !localIntent.freeText.isEmpty

        guard looksUnresolved else { return localIntent }

        do {
            let remoteIntent = try await remote.parse(trimmed, vocabulary: vocabulary)
            AppLog.ai.info("Remote parser resolved query into structured intent.")
            return merge(local: localIntent, remote: remoteIntent)
        } catch {
            AppLog.ai.notice("Remote parser unavailable, using on-device result.")
            return localIntent
        }
    }

    /// Prefer remote structure, but never lose constraints the on-device parser
    /// was confident about.
    private func merge(local: SearchIntent, remote: SearchIntent) -> SearchIntent {
        var result = remote
        if result.kinds.isEmpty { result.kinds = local.kinds }
        result.genres = Array(Set(result.genres).union(local.genres))
        if result.audioLanguages.isEmpty { result.audioLanguages = local.audioLanguages }
        if result.subtitleLanguages.isEmpty { result.subtitleLanguages = local.subtitleLanguages }
        result.minYear = result.minYear ?? local.minYear
        result.maxYear = result.maxYear ?? local.maxYear
        result.maxDurationMinutes = result.maxDurationMinutes ?? local.maxDurationMinutes
        result.minQuality = result.minQuality ?? local.minQuality
        result.timeContext = result.timeContext ?? local.timeContext
        return result
    }
}
