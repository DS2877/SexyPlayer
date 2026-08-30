import SwiftUI

/// Loads remote artwork, degrading gracefully to a restrained deterministic
/// gradient when there's no URL or the load fails.
///
/// Fills whatever frame it's given — callers set an explicit `.frame(...)`.
/// `style` controls the fallback: `.poster` shows the title's initials,
/// `.backdrop` shows just the gradient (initials over a wide backdrop look bad).
public struct ArtworkView: View {
    public enum Style { case poster, backdrop }

    let url: URL?
    let title: String
    let aspect: CGFloat
    var style: Style = .poster

    public init(url: URL?, title: String, aspect: CGFloat, style: Style = .poster) {
        self.url = url
        self.title = title
        self.aspect = aspect
        self.style = style
    }

    public var body: some View {
        ZStack {
            Palette.placeholderGradient(for: title)
            if let url {
                AsyncImage(url: url, transaction: .init(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .clipped()
        .accessibilityHidden(true)   // always decorative; the parent supplies the label
    }

    @ViewBuilder
    private var fallback: some View {
        switch style {
        case .backdrop:
            // Just the gradient, with a faint centre glow for depth.
            RadialGradient(colors: [.white.opacity(0.05), .clear], center: .center, startRadius: 0, endRadius: 600)
        case .poster:
            // A composed typographic poster so a missing image still reads as
            // curated art rather than an empty tile.
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [.white.opacity(0.07), .clear, .black.opacity(0.28)],
                                   startPoint: .top, endPoint: .bottom)
                    VStack(spacing: geo.size.height * 0.03) {
                        Image(systemName: "film")
                            .font(.system(size: geo.size.width * 0.11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.22))
                        Text(title)
                            .font(.system(size: geo.size.width * 0.13, weight: .semibold, design: .serif))
                            .foregroundStyle(.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(geo.size.width * 0.12)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
