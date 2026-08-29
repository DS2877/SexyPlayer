import SwiftUI

/// Shared cinematic layout for detail screens: full-bleed backdrop, darkening
/// gradients, and a left-aligned content column.
struct DetailScaffold<Content: View>: View {
    let title: String
    let backdropURL: URL?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                ArtworkView(url: backdropURL, title: title, aspect: 16.0 / 9.0)
                    .frame(height: 720)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Palette.canvas.opacity(0.7), Palette.canvas],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Palette.canvas.opacity(0.85), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )

                VStack(alignment: .leading, spacing: Metrics.space3) {
                    Spacer().frame(height: 380)
                    content()
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, Metrics.space7)
                .frame(maxWidth: 1400, alignment: .leading)
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
