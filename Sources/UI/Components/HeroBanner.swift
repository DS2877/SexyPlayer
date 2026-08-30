import SwiftUI

/// Home's featured banner. A full-bleed cinematic backdrop when the provider
/// gives us one; a composed two-column feature (text + a typographic poster)
/// when it doesn't, so the top of Home never reads as empty.
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

    private var hasArtwork: Bool { artworkURL != nil }

    public var body: some View {
        if hasArtwork {
            backdropHero
        } else {
            featureHero
        }
    }

    // MARK: - Copy + CTA (shared)

    private var copy: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Group {
                if !metadata.isEmpty {
                    Text(metadata.joined(separator: "   ·   "))
                        .font(.dsTag)
                        .foregroundStyle(Palette.textSecondary)
                        .textCase(.uppercase)
                        .tracking(Metrics.eyebrowTracking)
                }
                Text(title)
                    .font(.dsHero)
                    .lineLimit(2)
                    .tracking(Metrics.heroTracking)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
                if !tagline.isEmpty {
                    Text(tagline)
                        .font(.dsBody)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: 780, alignment: .leading)
                }
            }
            .accessibilityElement(children: .combine)

            Button(action: primaryAction) {
                Label(primaryActionTitle, systemImage: "info.circle")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, Metrics.space3)
            .accessibilityLabel("\(primaryActionTitle), \(title)")
        }
    }

    // MARK: - Backdrop layout (real artwork)

    private var backdropHero: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(url: artworkURL, title: title, aspect: 16.0 / 7.0, style: .backdrop)
                .frame(height: 620)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Palette.canvas.opacity(0.15), location: 0.35),
                            .init(color: Palette.canvas.opacity(0.7), location: 0.72),
                            .init(color: Palette.canvas.opacity(0.97), location: 0.92),
                            .init(color: Palette.canvas, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [Palette.canvas.opacity(0.8), Palette.canvas.opacity(0.2), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            copy
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, Metrics.space5)
        }
    }

    // MARK: - Feature layout (no artwork)

    private var featureHero: some View {
        copy
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.screenMargin)
            .frame(height: 360, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                RadialGradient(
                    colors: [Palette.accent.opacity(0.07), .clear],
                    center: UnitPoint(x: 0.2, y: 0.55), startRadius: 0, endRadius: 720
                )
            )
    }
}
