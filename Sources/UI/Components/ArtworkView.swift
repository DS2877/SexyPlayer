import SwiftUI

/// Loads remote artwork, degrading to a deterministic generated mesh when
/// there's no URL or the load fails.
///
/// Fills whatever frame it's given — callers set an explicit `.frame(...)`.
/// `style` controls the fallback: `.poster` composes a typographic poster over
/// the mesh; `.backdrop` shows just the mesh (text over a wide backdrop reads
/// badly).
public struct ArtworkView: View {
    public enum Style { case poster, backdrop }

    let url: URL?
    let title: String
    let aspect: CGFloat
    var style: Style = .poster
    /// How large this actually renders — drives the decode. `style` is about the
    /// *fallback*; a 16:9 episode still uses `.backdrop` styling but is only a
    /// card-sized image, so the two are set independently.
    var size: ImageSize = .poster

    public init(url: URL?, title: String, aspect: CGFloat,
                style: Style = .poster, size: ImageSize = .poster) {
        self.url = url
        self.title = title
        self.aspect = aspect
        self.style = style
        self.size = size
    }

    public var body: some View {
        ZStack {
            GeneratedArtwork(seed: title)
            if let url {
                CachedImage(url: url, size: size) { fallback }
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
            Color.clear   // the mesh underneath is enough
        case .poster:
            GeometryReader { geo in
                VStack(spacing: geo.size.height * 0.03) {
                    Image(systemName: "film")
                        .font(.system(size: geo.size.width * 0.10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.28))
                    Text(title)
                        .font(.system(size: geo.size.width * 0.125, weight: .semibold, design: .serif))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.55)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                }
                .padding(geo.size.width * 0.12)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
