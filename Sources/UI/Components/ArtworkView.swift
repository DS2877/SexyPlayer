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
            ZStack {
                LinearGradient(colors: [.white.opacity(0.05), .clear],
                               startPoint: .top, endPoint: .center)
                Text(initials)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var initials: String {
        let words = title.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
