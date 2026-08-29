import SwiftUI

/// Loads remote artwork, degrading gracefully to a deterministic gradient with
/// the title's initials when there's no URL or the load fails.
///
/// Fills whatever frame it's given — callers set an explicit `.frame(...)`.
/// M0 uses `AsyncImage`. M7 swaps in a downsampling disk-cached loader.
public struct ArtworkView: View {
    let url: URL?
    let title: String
    let aspect: CGFloat   // kept for call-site clarity; layout comes from the frame

    public init(url: URL?, title: String, aspect: CGFloat) {
        self.url = url
        self.title = title
        self.aspect = aspect
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
                        placeholderContent
                    @unknown default:
                        placeholderContent
                    }
                }
            } else {
                placeholderContent
            }
        }
        .clipped()
    }

    private var placeholderContent: some View {
        Text(initials)
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(.white.opacity(0.85))
            .shadow(radius: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var initials: String {
        let words = title.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }
}
