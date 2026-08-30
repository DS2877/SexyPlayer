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
                .frame(height: 640)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Palette.canvas.opacity(0.15), location: 0.35),
                            .init(color: Palette.canvas.opacity(0.65), location: 0.68),
                            .init(color: Palette.canvas.opacity(0.97), location: 0.9),
                            .init(color: Palette.canvas, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [Palette.canvas.opacity(0.85), Palette.canvas.opacity(0.25), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            VStack(alignment: .leading, spacing: Metrics.space2) {
                Group {
                    if !metadata.isEmpty {
                        Text(metadata.joined(separator: "   ·   "))
                            .font(.dsTag)
                            .foregroundStyle(Palette.textSecondary)
                            .textCase(.uppercase)
                            .tracking(Metrics.eyebrowTracking)
                    }
                    Text(title).font(.dsHero).lineLimit(2)
                        .tracking(Metrics.heroTracking)
                        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
                    if !tagline.isEmpty {
                        Text(tagline)
                            .font(.dsBody)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: 820, alignment: .leading)
                    }
                }
                .accessibilityElement(children: .combine)

                Button(action: primaryAction) {
                    Label(primaryActionTitle, systemImage: "info.circle")
                        .font(.dsCardTitle)
                        .padding(.horizontal, Metrics.space3)
                        .padding(.vertical, Metrics.space1)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Metrics.space2)
                .accessibilityLabel("\(primaryActionTitle), \(title)")
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, Metrics.space5)
        }
    }
}
