import SwiftUI

/// The Aeria+ wordmark — "Aeria+" in a heavy weight with a polished chrome
/// vertical gradient. Matches the app icon; used in the sidebar header and
/// anywhere the brand name is shown as a mark (not as body copy).
struct Wordmark: View {
    var size: CGFloat = 30

    static let chrome = LinearGradient(
        stops: [
            .init(color: Color(white: 0.98), location: 0.00),
            .init(color: Color(white: 0.68), location: 0.38),
            .init(color: Color(white: 0.46), location: 0.50),
            .init(color: Color(white: 0.95), location: 0.57),
            .init(color: Color(white: 0.78), location: 0.80),
            .init(color: Color(white: 0.62), location: 1.00),
        ],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        Text("Aeria+")
            .font(.system(size: size, weight: .heavy))
            .tracking(-size * 0.02)
            .foregroundStyle(Self.chrome)
            .shadow(color: .black.opacity(0.35), radius: size * 0.06, y: size * 0.03)
            .accessibilityLabel("Aeria plus")
    }
}
