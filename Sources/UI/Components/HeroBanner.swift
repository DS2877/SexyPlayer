import SwiftUI

/// Full-bleed cinematic banner at the top of Home.
public struct HeroBanner: View {
    let title: String
    let tagline: String
    let metadata: [String]
    let artworkURL: URL?
    let primaryActionTitle: String
    let primaryAction: () -> Void

    public init(
        title: String,
        tagline: String,
        metadata: [String] = [],
        artworkURL: URL? = nil,
        primaryActionTitle: String = "Play",
        primaryAction: @escaping () -> Void
    ) {
        self.title = title
        self.tagline = tagline
        self.metadata = metadata
        self.artworkURL = artworkURL
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(url: artworkURL, title: title, aspect: 16.0 / 7.0, style: .backdrop)
                .frame(height: 560)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Palette.canvas.opacity(0.1), Palette.canvas.opacity(0.5),
                                 Palette.canvas.opacity(0.95), Palette.canvas],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [Palette.canvas.opacity(0.9), Palette.canvas.opacity(0.3), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            VStack(alignment: .leading, spacing: Metrics.space2) {
                if !metadata.isEmpty {
                    Text(metadata.joined(separator: "   ·   "))
                        .font(.dsTag)
                        .foregroundStyle(Palette.accent)
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
                Text(title).font(.dsHero).lineLimit(2)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                if !tagline.isEmpty {
                    Text(tagline)
                        .font(.dsBody)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: 820, alignment: .leading)
                }
                Button(action: primaryAction) {
                    Label(primaryActionTitle, systemImage: "info.circle")
                        .font(.dsCardTitle)
                        .padding(.horizontal, Metrics.space3)
                        .padding(.vertical, Metrics.space1)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Metrics.space2)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, Metrics.space5)
        }
    }
}
