import SwiftUI

/// Applies the app-wide background and default text colour. Put this once near
/// the root.
public struct AppThemeBackground: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(Palette.canvas.ignoresSafeArea())
            .foregroundStyle(Palette.textPrimary)
            .tint(Palette.accent)
    }
}

public extension View {
    func appThemeBackground() -> some View { modifier(AppThemeBackground()) }
}

/// Standard card surface with a focus-driven elevation + lift. tvOS's `.card`
/// button style gives the parallax/press feel; this adds our colour treatment.
public struct SurfaceCard<Content: View>: View {
    private let content: Content
    private let isFocused: Bool

    public init(isFocused: Bool, @ViewBuilder content: () -> Content) {
        self.isFocused = isFocused
        self.content = content()
    }

    public var body: some View {
        content
            .background(isFocused ? Palette.surfaceElevated : Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(isFocused ? Palette.accent.opacity(0.9) : Palette.hairline,
                                  lineWidth: isFocused ? 3 : 1)
            )
            .shadow(color: .black.opacity(isFocused ? 0.55 : 0.0),
                    radius: isFocused ? 30 : 0, x: 0, y: isFocused ? 18 : 0)
    }
}
