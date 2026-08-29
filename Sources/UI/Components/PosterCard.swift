import SwiftUI

/// A 2:3 poster card for movies and series. Uses the tvOS `.card` button style
/// for the native focus parallax, with our colour + metadata treatment.
public struct PosterCard: View {
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let badge: String?
    let progress: Double?
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    public init(
        title: String,
        subtitle: String? = nil,
        artworkURL: URL? = nil,
        badge: String? = nil,
        progress: Double? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.badge = badge
        self.progress = progress
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Metrics.space1) {
                ZStack(alignment: .bottomLeading) {
                    ArtworkView(url: artworkURL, title: title, aspect: 2.0 / 3.0)
                        .frame(width: Metrics.posterWidth, height: Metrics.posterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))

                    if let badge {
                        Text(badge)
                            .font(.dsTag)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(Metrics.space1)
                    }

                    if let progress, progress > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(.white.opacity(0.25))
                                Rectangle().fill(Palette.accent)
                                    .frame(width: geo.size.width * min(1, max(0, progress)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .frame(width: Metrics.posterWidth)

                Text(title)
                    .font(.dsCardTitle)
                    .foregroundStyle(isFocused ? Palette.textPrimary : Palette.textSecondary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.dsCaption)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: Metrics.posterWidth, alignment: .leading)
        }
        .buttonStyle(.card)
        .accessibilityLabel(Text(subtitle.map { "\(title), \($0)" } ?? title))
    }
}
