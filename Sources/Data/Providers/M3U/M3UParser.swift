import Foundation

/// Parses an M3U / M3U8 playlist into a `RawCatalog`. M3U has no notion of
/// "channel vs movie vs episode", so we classify each entry by its group title,
/// URL shape, and name.
public enum M3UParser {

    struct Entry {
        var name: String
        var attributes: [String: String]
        var url: String
    }

    public static func parse(_ data: Data, providerID: String) throws -> RawCatalog {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ProviderError.playlistMalformed(reason: "not text")
        }
        return try parse(text: text, providerID: providerID)
    }

    public static func parse(text: String, providerID: String) throws -> RawCatalog {
        let lines = text.split(whereSeparator: { $0.isNewline }).map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.first(where: { !$0.isEmpty })?.hasPrefix("#EXTM3U") == true else {
            throw ProviderError.playlistMalformed(reason: "missing #EXTM3U header")
        }

        var entries: [Entry] = []
        var pendingName: String?
        var pendingAttrs: [String: String] = [:]

        for line in lines {
            if line.hasPrefix("#EXTINF:") {
                let (name, attrs) = parseExtInf(line)
                pendingName = name
                pendingAttrs = attrs
            } else if line.hasPrefix("#") || line.isEmpty {
                continue
            } else if let name = pendingName {
                entries.append(Entry(name: name, attributes: pendingAttrs, url: line))
                pendingName = nil
                pendingAttrs = [:]
            }
        }

        guard !entries.isEmpty else {
            throw ProviderError.playlistMalformed(reason: "no channels found")
        }

        var channels: [RawChannel] = []
        var vod: [RawVODItem] = []
        var episodes: [RawSeriesEpisode] = []

        for entry in entries {
            let group = entry.attributes["group-title"]
            switch classify(entry) {
            case .channel:
                channels.append(RawChannel(
                    providerKey: entry.attributes["tvg-id"].nonEmpty ?? entry.url,
                    displayName: entry.name,
                    groupTitle: group,
                    logo: entry.attributes["tvg-logo"].nonEmpty,
                    tvgID: entry.attributes["tvg-id"].nonEmpty,
                    streamURL: entry.url
                ))
            case .movie:
                vod.append(RawVODItem(
                    providerKey: entry.url,
                    name: entry.name,
                    groupTitle: group,
                    logo: entry.attributes["tvg-logo"].nonEmpty,
                    streamURL: entry.url
                ))
            case .episode:
                episodes.append(RawSeriesEpisode(
                    providerKey: entry.url,
                    name: entry.name,
                    groupTitle: group,
                    logo: entry.attributes["tvg-logo"].nonEmpty,
                    streamURL: entry.url
                ))
            }
        }

        return RawCatalog(providerID: providerID, channels: channels, vod: vod,
                          seriesEpisodes: episodes, seriesShells: [], epg: [])
    }

    // MARK: - Classification

    enum Classification { case channel, movie, episode }

    private static let episodeMarker = CompiledPattern(#"(?<![a-z])(s\d{1,2}[\s\-_.]*e\d{1,4}|\d{1,2}x\d{1,4}|season\s*\d{1,2})"#)

    static func classify(_ entry: Entry) -> Classification {
        let group = (entry.attributes["group-title"] ?? "").lowercased()
        let url = entry.url.lowercased()
        let name = entry.name.lowercased()

        if url.contains("/series/") || group.contains("series") || group.contains("serie ")
            || episodeMarker.matches(name) {
            return .episode
        }
        if url.contains("/movie/") || url.contains("/vod/")
            || group.contains("movie") || group.contains("vod") || group.contains("film")
            || url.hasSuffix(".mp4") || url.hasSuffix(".mkv") || url.hasSuffix(".avi") {
            return .movie
        }
        return .channel
    }

    // MARK: - #EXTINF

    static func parseExtInf(_ line: String) -> (name: String, attributes: [String: String]) {
        // #EXTINF:-1 tvg-id="x" group-title="z, w",Channel Name
        // The display name starts at the first comma that is NOT inside quotes;
        // attribute values themselves may contain commas.
        let afterColon = String(line.dropFirst("#EXTINF:".count))

        var inQuotes = false
        var splitIndex: String.Index?
        for i in afterColon.indices {
            let ch = afterColon[i]
            if ch == "\"" { inQuotes.toggle() }
            else if ch == "," && !inQuotes { splitIndex = i; break }
        }

        let attrPart: String
        let name: String
        if let splitIndex {
            attrPart = String(afterColon[..<splitIndex])
            name = String(afterColon[afterColon.index(after: splitIndex)...])
                .trimmingCharacters(in: .whitespaces)
        } else {
            attrPart = afterColon
            name = ""
        }

        var attributes: [String: String] = [:]
        let range = NSRange(attrPart.startIndex..., in: attrPart)
        if let regex = try? NSRegularExpression(pattern: #"([a-zA-Z0-9\-_]+)="([^"]*)""#) {
            for match in regex.matches(in: attrPart, range: range) {
                guard let kR = Range(match.range(at: 1), in: attrPart),
                      let vR = Range(match.range(at: 2), in: attrPart) else { continue }
                attributes[String(attrPart[kR]).lowercased()] = String(attrPart[vR])
            }
        }
        return (name, attributes)
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let self, !self.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return self
    }
}
