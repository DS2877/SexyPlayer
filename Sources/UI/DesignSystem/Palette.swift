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

    /// Single accent — a bright premium blue, tied to the Aeria+ mark. Used
    /// sparingly: progress fills, ratings, small selected-state marks, the app
    /// `.tint`. Also mirrored in Assets/AccentColor.
    public static let accent = Color(red: 0.231, green: 0.620, blue: 1.0)             // #3B9EFF
    public static let accentSoft = accent.opacity(0.16)

    /// Bright fill for a focused control — dark label rides on top (Apple TV app).
    public static let focusFill = Color(red: 0.96, green: 0.96, blue: 0.965)

    public static let liveDot = Color(red: 0.918, green: 0.263, blue: 0.337)
    public static let hairline = Color.white.opacity(0.06)
}
