import Foundation

/// Parses an XMLTV document into `[RawEPGEvent]`.
///
/// URLSession transparently inflates `Content-Encoding: gzip` responses, which
/// covers the common Xtream `xmltv.php` case. A literal gzip *file* (`.xml.gz`
/// served as octet-stream) is detected and reported rather than mis-parsed;
/// full `.gz` support can be added if a real provider needs it.
public enum XMLTVParser {

    public static func parse(_ data: Data) throws -> [RawEPGEvent] {
        if data.count >= 2, data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b {
            throw ProviderError.playlistMalformed(reason: "EPG is a gzip file; not yet supported")
        }

        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw ProviderError.playlistMalformed(reason: "invalid XMLTV")
        }
        return delegate.events
    }

    // MARK: - SAX delegate

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var events: [RawEPGEvent] = []

        private var currentChannel: String?
        private var currentStart: Date?
        private var currentStop: Date?
        private var currentElement: String?
        private var title = ""
        private var subtitle = ""
        private var desc = ""
        private var category = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String]) {
            currentElement = elementName
            if elementName == "programme" {
                currentChannel = attributeDict["channel"]
                currentStart = Self.parseDate(attributeDict["start"])
                currentStop = Self.parseDate(attributeDict["stop"])
                title = ""; subtitle = ""; desc = ""; category = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            switch currentElement {
            case "title":     title += string
            case "sub-title": subtitle += string
            case "desc":      desc += string
            case "category":  if category.isEmpty { category += string }
            default: break
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "programme" {
                if let channel = currentChannel, let start = currentStart, let stop = currentStop,
                   stop > start {
                    events.append(RawEPGEvent(
                        channelID: channel,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("Programme"),
                        subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                        description: desc.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                        start: start,
                        stop: stop,
                        category: category.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ))
                }
                currentChannel = nil; currentStart = nil; currentStop = nil
            }
            currentElement = nil
        }

        /// XMLTV timestamps: `20240115203000 +0100` (offset optional).
        static func parseDate(_ raw: String?) -> Date? {
            guard let raw = raw?.trimmingCharacters(in: .whitespaces), raw.count >= 14 else { return nil }
            let digits = String(raw.prefix(14))
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMddHHmmss"

            let tzPart = raw.dropFirst(14).trimmingCharacters(in: .whitespaces)
            if tzPart.count == 5, let hours = Int(tzPart.prefix(3)), let mins = Int(tzPart.suffix(2)) {
                formatter.timeZone = TimeZone(secondsFromGMT: hours * 3600 + (hours < 0 ? -mins : mins) * 60)
            } else {
                formatter.timeZone = TimeZone(identifier: "UTC")
            }
            return formatter.date(from: digits)
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
