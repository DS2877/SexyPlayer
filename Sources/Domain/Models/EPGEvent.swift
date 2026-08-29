import Foundation

/// A single programme in the electronic programme guide.
public struct EPGEvent: Identifiable, Hashable, Codable, Sendable {
    public var id: String { "\(channelEPGID)@\(start.timeIntervalSince1970)" }

    /// Joins to `Channel.epgID`.
    public let channelEPGID: String
    public let title: String
    public let subtitle: String?
    public let description: String?
    public let start: Date
    public let stop: Date
    public let category: String?

    public init(
        channelEPGID: String,
        title: String,
        subtitle: String? = nil,
        description: String? = nil,
        start: Date,
        stop: Date,
        category: String? = nil
    ) {
        self.channelEPGID = channelEPGID
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.start = start
        self.stop = stop
        self.category = category
    }

    public var duration: TimeInterval { stop.timeIntervalSince(start) }

    public func isLive(at date: Date) -> Bool {
        date >= start && date < stop
    }

    /// Progress 0...1 through the event at `date`, clamped.
    public func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / duration))
    }
}
