import SwiftUI

/// Spacing, sizing and typography tokens. tvOS renders on a 1920×1080 canvas
/// with significant overscan — the safe-area insets from SwiftUI handle the
/// screen edge, and `Metrics.screenMargin` is the extra breathing room premium
/// streaming apps use.
public enum Metrics {
    // 8-pt spacing scale
    public static let space1: CGFloat = 8
    public static let space2: CGFloat = 16
    public static let space3: CGFloat = 24
    public static let space4: CGFloat = 32
    public static let space5: CGFloat = 48
    public static let space6: CGFloat = 64
    public static let space7: CGFloat = 96

    public static let screenMargin: CGFloat = 90
    /// Vertical gap between Home shelves — deliberately generous, Apple TV+ style.
    public static let shelfSpacing: CGFloat = 64
    public static let cardSpacing: CGFloat = 28

    public static let cornerRadius: CGFloat = 14
    public static let cardCornerRadius: CGFloat = 10

    // Poster cards (2:3)
    public static let posterWidth: CGFloat = 258
    public static var posterHeight: CGFloat { posterWidth * 3 / 2 }

    // Channel / 16:9 cards
    public static let wideCardWidth: CGFloat = 300
    public static var wideCardHeight: CGFloat { wideCardWidth * 9 / 16 }

    public static let focusScale: CGFloat = 1.10
    public static let focusAnimation: Animation = .spring(response: 0.34, dampingFraction: 0.74)

    /// Tracking for the big display title — SF Pro reads better drawn tight.
    public static let heroTracking: CGFloat = -0.5
    /// Tracking for uppercase eyebrow / tag text.
    public static let eyebrowTracking: CGFloat = 1.6
}

public extension Font {
    static let dsHero = Font.system(size: 66, weight: .bold, design: .default)
    static let dsTitle = Font.system(size: 40, weight: .semibold)
    static let dsSectionHeader = Font.system(size: 27, weight: .semibold)
    static let dsCardTitle = Font.system(size: 23, weight: .medium)
    static let dsBody = Font.system(size: 24, weight: .regular)
    static let dsCaption = Font.system(size: 19, weight: .regular)
    static let dsTag = Font.system(size: 16, weight: .semibold)
}
