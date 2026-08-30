import SwiftUI

/// Shared cinematic layout for detail screens: full-bleed backdrop, darkening
/// gradients, and a left-aligned content column.
struct DetailScaffold<Content: View>: View {
    let title: String
    let backdropURL: URL?
    @ViewBuilder let content: () -> Content

    private let backdropHeight: CGFloat = 680

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                ArtworkView(url: backdropURL, title: title, aspect: 16.0 / 9.0, style: .backdrop)
                    .frame(height: backdropHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Palette.canvas.opacity(0.2), location: 0.4),
                                .init(color: Palette.canvas.opacity(0.7), location: 0.72),
                                .init(color: Palette.canvas.opacity(0.97), location: 0.92),
                                .init(color: Palette.canvas, location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Palette.canvas.opacity(0.85), Palette.canvas.opacity(0.3), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )

                VStack(alignment: .leading, spacing: Metrics.space3) {
                    Spacer().frame(height: backdropHeight * 0.52)
                    content()
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, Metrics.space7)
                .frame(maxWidth: 1320, alignment: .leading)
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }
}

/// A labelled row of language chips ("English audio", "Swedish subtitles").
struct LanguageSummary: View {
    let audio: [Language]
    let subtitles: [Language]

    var body: some View {
        if !audio.isEmpty || !subtitles.isEmpty {
            HStack(spacing: Metrics.space2) {
                if !audio.isEmpty {
                    chip("Audio", audio.map(\.displayName).joined(separator: ", "))
                }
                if !subtitles.isEmpty {
                    chip("Subtitles", subtitles.map(\.displayName).joined(separator: ", "))
                }
            }
        }
    }

    private func chip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.dsTag).foregroundStyle(Palette.textTertiary)
            Text(value).font(.dsTag).foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Metrics.space2)
        .padding(.vertical, Metrics.space1)
        .background(Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.hairline))
    }
}
