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
