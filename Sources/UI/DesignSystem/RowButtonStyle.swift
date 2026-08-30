import SwiftUI

/// A full-width list row that reacts to focus with a surface fill + gentle lift.
/// Use for settings rows, example queries, pickable list items — anywhere a
/// `.card` poster style would be wrong but `.plain` gives no feedback.
public struct RowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        RowButtonBody(configuration: configuration)
    }
}

private struct RowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .padding(.horizontal, Metrics.space3)
            .padding(.vertical, Metrics.space2 + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                    .fill(isFocused ? Palette.surfaceElevated : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(isFocused ? 0.16 : 0.0), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isFocused ? 0.4 : 0.0),
                    radius: isFocused ? 24 : 0, y: isFocused ? 14 : 0)
            .scaleEffect(isFocused ? 1.02 : 1)
            .animation(Metrics.focusAnimation, value: isFocused)
    }
}

// MARK: - CTA buttons

/// The primary call to action — a bright pill, dark label. Apple TV app "Play".
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        CTABody(configuration: configuration, prominent: true)
    }
}

/// A quiet translucent pill for secondary actions.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        CTABody(configuration: configuration, prominent: false)
    }
}

private struct CTABody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled

    private var fill: Color {
        if prominent { return isFocused ? .white : Color(white: 0.92) }
        return isFocused ? Palette.focusFill : Color.white.opacity(0.14)
    }
    private var label: Color {
        if prominent { return Palette.canvas }
        return isFocused ? Palette.canvas : Palette.textPrimary
    }

    var body: some View {
        configuration.label
            .font(.dsCardTitle)
            .foregroundStyle(label)
            .padding(.horizontal, prominent ? Metrics.space4 : Metrics.space3)
            .padding(.vertical, Metrics.space2)
            .background(Capsule().fill(fill))
            .scaleEffect(isFocused ? 1.06 : 1)
            .shadow(color: .black.opacity(isFocused ? 0.45 : (prominent ? 0.12 : 0)),
                    radius: isFocused ? 28 : 6, y: isFocused ? 16 : 3)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .animation(Metrics.focusAnimation, value: isFocused)
    }
}
