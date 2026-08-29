import Foundation

/// Best-effort detection of adult categories so the user can hide them. Matches
/// on obvious markers in the name or group title. Conservative — it won't catch
/// everything, and it errs toward *not* flagging borderline cases.
public enum AdultContentDetector {

    private static let markers = CompiledPattern(
        #"(?<![a-z])(xxx|18\+|adults?[\s\-]?only|porn\w*|erotic\w*|hardcore|nsfw|for\s?adults)(?![a-z])"#
    )
    private static let groupMarkers: Set<String> = [
        "xxx", "adult", "adults", "porn", "erotic", "erotica", "18+", "for adults", "adult movies",
    ]

    public static func isAdult(name: String, groupTitle: String?) -> Bool {
        if let g = groupTitle?.lowercased() {
            if groupMarkers.contains(where: { g.contains($0) }) { return true }
        }
        if markers.matches(name.lowercased()) { return true }
        return false
    }
}
