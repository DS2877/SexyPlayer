import SwiftUI

/// Colour tokens. The app is dark-only (declared in Info.plist) so these are
/// tuned for a cinematic near-black canvas.
public enum Palette {
    /// App background — the darkest layer.
    public static let canvas = Color(red: 0.039, green: 0.039, blue: 0.047)          // #0A0A0C
    /// Cards and raised surfaces.
    public static let surface = Color(red: 0.086, green: 0.090, blue: 0.106)         // #16171B
    /// Surface when focused / hovered.
    public static let surfaceElevated = Color(red: 0.137, green: 0.145, blue: 0.169) // #23252B

    public static let textPrimary = Color(red: 0.965, green: 0.969, blue: 0.980)
    public static let textSecondary = Color(red: 0.639, green: 0.659, blue: 0.706)
    public static let textTertiary = Color(red: 0.427, green: 0.443, blue: 0.486)

    /// Single accent — warm gold, tied to the beige/charcoal brand mark.
    /// Also mirrored in Assets/AccentColor.
    public static let accent = Color(red: 0.859, green: 0.671, blue: 0.325)           // #DBAB53
    public static let accentSoft = accent.opacity(0.15)

    public static let liveDot = Color(red: 0.918, green: 0.263, blue: 0.337)
    public static let hairline = Color.white.opacity(0.08)

    /// Deterministic placeholder artwork — a small set of restrained, cinematic
    /// dark gradients so a grid of missing-poster cards reads as one palette
    /// rather than a bag of colours.
    private static let placeholderPairs: [(top: Color, bottom: Color)] = [
        (Color(red: 0.16, green: 0.15, blue: 0.13), Color(red: 0.07, green: 0.065, blue: 0.055)),  // warm charcoal
        (Color(red: 0.13, green: 0.15, blue: 0.17), Color(red: 0.06, green: 0.07, blue: 0.085)),   // slate
        (Color(red: 0.15, green: 0.145, blue: 0.17), Color(red: 0.07, green: 0.065, blue: 0.09)),  // plum-grey
        (Color(red: 0.13, green: 0.16, blue: 0.15), Color(red: 0.06, green: 0.08, blue: 0.075)),   // deep pine
        (Color(red: 0.17, green: 0.15, blue: 0.14), Color(red: 0.08, green: 0.065, blue: 0.06)),   // umber
    ]

    public static func placeholderGradient(for seed: String) -> LinearGradient {
        let pair = placeholderPairs[Int(StableHash.hash(seed) % UInt64(placeholderPairs.count))]
        return LinearGradient(colors: [pair.top, pair.bottom],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
