import SwiftUI

/// A 2:3 poster with its caption beneath. Only the artwork is the focusable
/// `.card` — the title and metadata sit outside it, the way the Apple TV app
/// lays out a poster shelf, so nothing gets clipped by the card's corners.
public struct PosterCard: View {
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let badge: String?
    let progress: Double?
    let action: () -> Void

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

    private var captionLine: String {
        if let subtitle, !subtitle.isEmpty { return subtitle }
        return artworkURL == nil ? "" : title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space1 + 2) {
            Button(action: action) {
                ZStack(alignment: .topTrailing) {
                    ArtworkView(url: artworkURL, title: title, aspect: 2.0 / 3.0)
                        .frame(width: Metrics.posterWidth, height: Metrics.posterHeight)
                        .overlay(alignment: .bottom) {
                            if (progress ?? 0) > 0 {
                                ZStack(alignment: .bottomLeading) {
                                    LinearGradient(colors: [.clear, .black.opacity(0.6)],
                                                   startPoint: .center, endPoint: .bottom)
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.white.opacity(0.28))
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

                    if let badge {
                        Text(badge)
                            .font(.dsTag)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(Metrics.space1)
                    }
                }
            }
            .buttonStyle(.card)

            VStack(alignment: .leading, spacing: 3) {
                // With no artwork the poster itself carries the title, so the
                // caption drops to just the metadata line.
                if artworkURL != nil {
                    Text(title)
                        .font(.dsCardTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                }
                if !captionLine.isEmpty {
                    Text(captionLine)
                        .font(.dsCaption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
            .frame(minHeight: 30, alignment: .top)
        }
        .frame(width: Metrics.posterWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(subtitle.map { "\(title), \($0)" } ?? title))
        .accessibilityAddTraits(.isButton)
    }
}
