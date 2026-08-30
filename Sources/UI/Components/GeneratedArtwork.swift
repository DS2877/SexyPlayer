import SwiftUI

/// A deterministic, moody fill used wherever a title has no real artwork. Same
/// seed always renders the same art. Built from a couple of cheap gradients
/// (not `MeshGradient`) so a scrolling grid of these stays at 60fps.
struct GeneratedArtwork: View {
    let seed: String

    var body: some View {
        let hash = StableHash.hash(seed)
        let baseHue = Double(hash % 360) / 360.0
        let r = Self.stream(hash)

        let top = Color(hue: Self.wrap(baseHue - 0.02), saturation: 0.24 + r() * 0.08, brightness: 0.15 + r() * 0.04)
        let bottom = Color(hue: Self.wrap(baseHue + 0.03), saturation: 0.22, brightness: 0.075)
        let accentHue = Self.wrap(baseHue + 0.42 + (r() - 0.5) * 0.1)
        let glow = Color(hue: accentHue, saturation: 0.30, brightness: 0.16)
        let glowX = 0.2 + r() * 0.6
        let glowY = 0.15 + r() * 0.5

        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [glow.opacity(0.6), .clear],
                           center: UnitPoint(x: glowX, y: glowY), startRadius: 0, endRadius: 240)
                .blendMode(.plusLighter)
            LinearGradient(colors: [.white.opacity(0.05), .clear, .black.opacity(0.22)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Deterministic RNG

    private static func stream(_ seed: UInt64) -> () -> Double {
        var state = seed == 0 ? 0x1234_5678_9ABC_DEF0 : seed
        return {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 40) / Double(1 << 24)
        }
    }

    private static func wrap(_ hue: Double) -> Double {
        let m = hue.truncatingRemainder(dividingBy: 1.0)
        return m < 0 ? m + 1 : m
    }
}
