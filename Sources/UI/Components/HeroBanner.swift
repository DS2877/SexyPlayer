import SwiftUI

/// Home's featured banner — a rotating set of top titles with a full-bleed
/// cinematic backdrop (resolved from TMDB when the provider gave none). The
/// backdrop + copy crossfade on a timer; the action button and page dots stay
/// put so focus is never dropped mid-rotation.
struct HeroBanner: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let heroes: [HomeCard]
    let onSelect: (HomeCard) -> Void

    @State private var index = 0
    @State private var overview: String?
    @FocusState private var buttonFocused: Bool

    private let interval: Duration = .seconds(9)
    private let height: CGFloat = 620

    private var current: HomeCard? {
        guard !heroes.isEmpty else { return nil }
        return heroes[min(index, heroes.count - 1)]
    }

    /// Restart the rotation whenever the set *or its lead item* changes, not just
    /// its length.
    private var heroKey: String { "\(heroes.count)-\(heroes.first?.id.rawValue ?? "")" }

    var body: some View {
        if let hero = current {
            ZStack(alignment: .bottomLeading) {
                backdrop(for: hero)
                overlayContent(for: hero)
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .task(id: hero.id) { await resolveOverview(for: hero) }
            .task(id: heroKey) {
                if index >= heroes.count { index = 0 }
                await rotate()
            }
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private func backdrop(for hero: HomeCard) -> some View {
        ZStack {
            if let ref = hero.artworkRef {
                EnrichedArtwork(ref: ref, providerURL: hero.artworkURL,
                                aspect: 16.0 / 7.0, style: .backdrop)
            } else {
                ArtworkView(url: hero.artworkURL, title: hero.title, aspect: 16.0 / 7.0, style: .backdrop)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .id(hero.id)
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: hero.id)
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
    }

    private func overlayContent(for hero: HomeCard) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Group {
                if let eyebrow = hero.eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(.dsTag)
                        .foregroundStyle(Palette.textSecondary)
                        .textCase(.uppercase)
                        .tracking(Metrics.eyebrowTracking)
                }
                Text(hero.title)
                    .font(.dsHero)
                    .lineLimit(2)
                    .tracking(Metrics.heroTracking)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
                if let line = overview ?? hero.subtitle, !line.isEmpty {
                    Text(line)
                        .font(.dsBody)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: 780, alignment: .leading)
                }
            }
            .id(hero.id)
            .transition(.opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: hero.id)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: overview)
            .accessibilityElement(children: .combine)

            HStack(alignment: .center, spacing: Metrics.space2) {
                Button { onSelect(hero) } label: {
                    Label("More Info", systemImage: "info.circle")
                }
                .buttonStyle(PrimaryButtonStyle())
                .focused($buttonFocused)
                .accessibilityLabel("More Info, \(hero.title)")

                if heroes.count > 1 { pageDots }
            }
            .padding(.top, Metrics.space3)
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.bottom, Metrics.space5)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(heroes.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Palette.textPrimary : Palette.textPrimary.opacity(0.25))
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: index)
        .accessibilityHidden(true)
    }

    // MARK: - Behaviour

    private func resolveOverview(for hero: HomeCard) async {
        overview = nil
        guard let ref = hero.artworkRef else { return }
        let meta = await env.metadata.metadata(
            for: ref.id, title: ref.title, year: ref.year, isSeries: ref.isSeries
        )
        if let text = meta?.overview { overview = text }
    }

    private func rotate() async {
        // Reduce Motion: hold on the top title, no auto-advance.
        guard heroes.count > 1, !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled, !buttonFocused else { continue }
            withAnimation(.easeInOut(duration: 0.6)) {
                index = (index + 1) % heroes.count
            }
        }
    }
}
