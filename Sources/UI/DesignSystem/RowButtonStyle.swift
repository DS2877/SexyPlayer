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
            .padding(.vertical, Metrics.space2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                    .fill(isFocused ? Palette.surfaceElevated : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(isFocused ? Palette.accent : Palette.hairline,
                                  lineWidth: isFocused ? 2 : 1)
            )
            .scaleEffect(isFocused ? 1.015 : 1)
            .animation(Metrics.focusAnimation, value: isFocused)
    }
}
