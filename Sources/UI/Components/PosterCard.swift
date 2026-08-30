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

    private var clampedProgress: Double { Swift.min(1, Swift.max(0, progress ?? 0)) }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Metrics.space1) {
                ZStack(alignment: .topLeading) {
                    ArtworkView(url: artworkURL, title: title, aspect: 2.0 / 3.0)
                        .frame(width: Metrics.posterWidth, height: Metrics.posterHeight)
                        .overlay(alignment: .bottom) {
                            if (progress ?? 0) > 0 {
                                ZStack(alignment: .bottomLeading) {
                                    LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                                   startPoint: .center, endPoint: .bottom)
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.white.opacity(0.25))
                                        Capsule().fill(Palette.accent)
                                            .frame(width: Swift.max(4, (Metrics.posterWidth - 24) * clampedProgress))
                                    }
                                    .frame(height: 4)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(isFocused ? 0.55 : 0),
                                radius: isFocused ? 28 : 0, y: isFocused ? 16 : 0)

                    if let badge {
                        Text(badge)
                            .font(.dsTag)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(Metrics.space1)
                    }
                }
                .frame(width: Metrics.posterWidth)

                Text(title)
                    .font(.dsCardTitle)
                    .foregroundStyle(isFocused ? Palette.textPrimary : Palette.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 2)

                if let subtitle, !subtitle.isEmpty {
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
