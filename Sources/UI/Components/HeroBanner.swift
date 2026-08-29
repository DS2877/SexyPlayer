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
            ArtworkView(url: artworkURL, title: title, aspect: 16.0 / 6.0)
                .frame(height: 620)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Palette.canvas.opacity(0.0), Palette.canvas.opacity(0.6), Palette.canvas],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [Palette.canvas.opacity(0.75), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            VStack(alignment: .leading, spacing: Metrics.space2) {
                Text(title).font(.dsHero).lineLimit(2)
                Text(tagline)
                    .font(.dsBody)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: 900, alignment: .leading)
                if !metadata.isEmpty {
                    MetadataLine(metadata.map { $0 as String? })
                }
                Button(action: primaryAction) {
                    Label(primaryActionTitle, systemImage: "play.fill")
                        .font(.dsCardTitle)
                        .padding(.horizontal, Metrics.space3)
                        .padding(.vertical, Metrics.space1)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Metrics.space1)
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, Metrics.space4)
        }
    }
}
