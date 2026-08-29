import Foundation

/// Small, allocation-light wrapper around `NSRegularExpression` for the
/// normalization layer. Patterns are compiled once and cached.
public struct CompiledPattern: Sendable {
    private let regex: NSRegularExpression

    public init(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) {
        // Patterns are compile-time constants in this codebase; a bad one is a
        // programmer error we want to catch immediately.
        // swiftlint:disable:next force_try
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
    }

    public func matches(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }

    /// Capture groups of the first match. Index 0 is the whole match. Missing
    /// groups are `nil`.
    public func firstMatchGroups(_ string: String) -> [String?]? {
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { i in
            let r = match.range(at: i)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: string) else { return nil }
            return String(string[swiftRange])
        }
    }

    /// Remove every match from `string`.
    public func removingMatches(in string: String) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "")
    }
}
