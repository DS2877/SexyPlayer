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

    public static let screenMargin: CGFloat = 80
    public static let shelfSpacing: CGFloat = 56
    public static let cardSpacing: CGFloat = 32

    public static let cornerRadius: CGFloat = 12
    public static let cardCornerRadius: CGFloat = 10

    // Poster cards (2:3)
    public static let posterWidth: CGFloat = 240
    public static var posterHeight: CGFloat { posterWidth * 3 / 2 }

    // Channel / 16:9 cards
    public static let wideCardWidth: CGFloat = 360
    public static var wideCardHeight: CGFloat { wideCardWidth * 9 / 16 }

    public static let focusScale: CGFloat = 1.08
    public static let focusAnimation: Animation = .spring(response: 0.32, dampingFraction: 0.72)
}

public extension Font {
    static let dsHero = Font.system(size: 64, weight: .bold, design: .default)
    static let dsTitle = Font.system(size: 42, weight: .semibold)
    static let dsSectionHeader = Font.system(size: 30, weight: .semibold)
    static let dsCardTitle = Font.system(size: 24, weight: .medium)
    static let dsBody = Font.system(size: 24, weight: .regular)
    static let dsCaption = Font.system(size: 20, weight: .regular)
    static let dsTag = Font.system(size: 18, weight: .semibold)
}
