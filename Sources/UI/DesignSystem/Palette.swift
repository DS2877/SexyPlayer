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

    /// Single accent — also mirrored in Assets/AccentColor.
    public static let accent = Color(red: 0.310, green: 0.404, blue: 0.949)          // #4F67F2
    public static let accentSoft = accent.opacity(0.16)

    public static let liveDot = Color(red: 0.918, green: 0.263, blue: 0.337)
    public static let hairline = Color.white.opacity(0.08)

    /// Deterministic accent gradient for placeholder artwork, keyed off a string.
    public static func placeholderGradient(for seed: String) -> LinearGradient {
        let hue = Double(StableHash.hash(seed) % 360) / 360.0
        let base = Color(hue: hue, saturation: 0.42, brightness: 0.38)
        let dark = Color(hue: hue, saturation: 0.55, brightness: 0.16)
        return LinearGradient(colors: [base, dark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
