import SwiftUI

/// Full-bleed cinematic banner at the top of Home. Falls back to a tighter,
/// deliberately-composed panel when the provider gives us no backdrop.
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
    private var height: CGFloat { hasArtwork ? 620 : 396 }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop

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
                            .frame(maxWidth: 820, alignment: .leading)
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
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, Metrics.space5)
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        if hasArtwork {
            ArtworkView(url: artworkURL, title: title, aspect: 16.0 / 7.0, style: .backdrop)
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(bottomScrim)
                .overlay(leadingScrim)
        } else {
            // No backdrop: a quiet vignette panel so the hero reads as designed,
            // not as empty space.
            ZStack {
                Palette.canvas
                RadialGradient(
                    colors: [Palette.accent.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.22, y: 0.9),
                    startRadius: 0, endRadius: 720
                )
                LinearGradient(
                    colors: [.white.opacity(0.04), .clear],
                    startPoint: .top, endPoint: .center
                )
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(bottomScrim)
        }
    }

    private var bottomScrim: some View {
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
    }

    private var leadingScrim: some View {
        LinearGradient(
            colors: [Palette.canvas.opacity(0.8), Palette.canvas.opacity(0.2), .clear],
            startPoint: .leading, endPoint: .trailing
        )
    }
}
