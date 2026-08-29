import Foundation

/// Detects video quality from a raw channel/movie name or group title.
/// Pure and deterministic — see `QualityDetectorTests`.
public enum QualityDetector {

    private static let uhd = CompiledPattern(#"(?<![a-z])(4k|uhd|2160p?|ultra\s?hd)(?![a-z])"#)
    private static let fhd = CompiledPattern(#"(?<![a-z])(fhd|1080p?|full\s?hd)(?![a-z])"#)
    private static let hd  = CompiledPattern(#"(?<![a-z])(hd|720p?)(?![a-z])"#)
    private static let sd  = CompiledPattern(#"(?<![a-z])(sd|480p?|360p?|240p?|ld)(?![a-z])"#)

    public static func detect(in text: String) -> VideoQuality {
        let s = text.lowercased()
        if uhd.matches(s) { return .uhd }
        if fhd.matches(s) { return .fhd }
        if hd.matches(s)  { return .hd }
        if sd.matches(s)  { return .sd }
        return .unknown
    }

    /// Detect using several candidate strings, keeping the highest quality found.
    public static func detect(in candidates: [String?]) -> VideoQuality {
        candidates
            .compactMap { $0 }
            .map(detect(in:))
            .max() ?? .unknown
    }
}
