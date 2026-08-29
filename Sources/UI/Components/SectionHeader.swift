import SwiftUI

public struct SectionHeader: View {
    let title: String
    let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.dsSectionHeader).foregroundStyle(Palette.textPrimary)
            if let subtitle {
                Text(subtitle).font(.dsCaption).foregroundStyle(Palette.textTertiary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
