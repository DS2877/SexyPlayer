import SwiftUI

/// A removable/selectable pill used for interpreted search filters and browse
/// filters.
public struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let showsRemoveIcon: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    public init(
        label: String,
        isSelected: Bool = false,
        showsRemoveIcon: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isSelected = isSelected
        self.showsRemoveIcon = showsRemoveIcon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label).font(.dsTag)
                if showsRemoveIcon {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding(.horizontal, Metrics.space2)
            .padding(.vertical, Metrics.space1 + 2)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Palette.accent : Palette.hairline, lineWidth: 2))
            .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if isFocused { return Palette.surfaceElevated }
        return isSelected ? Palette.accentSoft : Palette.surface
    }
}
