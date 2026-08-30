import SwiftUI

/// Colour tokens. The app is dark-only (declared in Info.plist) so these are
/// tuned for a cinematic near-black canvas.
public enum Palette {
    /// App background — near-black, the way Apple TV+ sits behind its artwork.
    public static let canvas = Color(red: 0.031, green: 0.031, blue: 0.039)          // #08080A
    /// Cards and raised surfaces — barely lifted off the canvas.
    public static let surface = Color(red: 0.075, green: 0.078, blue: 0.090)         // #131417
    /// Surface when focused / hovered.
    public static let surfaceElevated = Color(red: 0.121, green: 0.125, blue: 0.141) // #1F2024

    // Apple's on-dark label ramp — crisp white down to a quiet tertiary grey.
    public static let textPrimary = Color(red: 0.961, green: 0.961, blue: 0.969)     // #F5F5F7
    public static let textSecondary = Color(red: 0.596, green: 0.596, blue: 0.624)   // #98989F
    public static let textTertiary = Color(red: 0.388, green: 0.388, blue: 0.400)    // #636366

    /// Single accent — warm gold, tied to the beige/charcoal brand mark. Used
    /// sparingly: progress, the live dot, small selected-state marks.
    /// Also mirrored in Assets/AccentColor.
    public static let accent = Color(red: 0.859, green: 0.671, blue: 0.325)           // #DBAB53
    public static let accentSoft = accent.opacity(0.14)

    /// Bright fill for a focused control — dark label rides on top (Apple TV app).
    public static let focusFill = Color(red: 0.96, green: 0.96, blue: 0.965)

    public static let liveDot = Color(red: 0.918, green: 0.263, blue: 0.337)
    public static let hairline = Color.white.opacity(0.06)

    /// Deterministic placeholder artwork — a small set of restrained, cinematic
    /// dark gradients so a grid of missing-poster cards reads as one palette
    /// rather than a bag of colours.
    private static let placeholderPairs: [(top: Color, bottom: Color)] = [
        (Color(red: 0.22, green: 0.20, blue: 0.17), Color(red: 0.09, green: 0.082, blue: 0.070)),  // warm charcoal
        (Color(red: 0.17, green: 0.20, blue: 0.24), Color(red: 0.072, green: 0.085, blue: 0.105)), // slate blue
        (Color(red: 0.21, green: 0.18, blue: 0.24), Color(red: 0.088, green: 0.076, blue: 0.108)), // plum
        (Color(red: 0.16, green: 0.21, blue: 0.19), Color(red: 0.070, green: 0.094, blue: 0.086)), // deep pine
        (Color(red: 0.24, green: 0.19, blue: 0.16), Color(red: 0.10, green: 0.078, blue: 0.066)),  // umber
    ]

    public static func placeholderGradient(for seed: String) -> LinearGradient {
        let pair = placeholderPairs[Int(StableHash.hash(seed) % UInt64(placeholderPairs.count))]
        return LinearGradient(colors: [pair.top, pair.bottom],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
