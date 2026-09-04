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

    /// Backing for a `pinnedViews: [.sectionHeaders]` header. An opaque canvas
    /// fill plus a 1px bottom hairline, so a scrolled-under header reads as a
    /// clean bar flush to the top instead of a translucent strip that ghosts
    /// the content sliding behind it. Pair with a scroll-away spacer above the
    /// `Section` for the at-rest breathing room.
    func pinnedHeaderStyle() -> some View {
        self
            .padding(.top, Metrics.space2)
            .padding(.bottom, Metrics.space3)
            .background(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    Palette.canvas
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                }
            }
    }
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
                    .strokeBorder(.white.opacity(isFocused ? 0.14 : 0.0), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0.0),
                    radius: isFocused ? 34 : 0, x: 0, y: isFocused ? 20 : 0)
    }
}
