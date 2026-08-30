import SwiftUI

/// A deterministic, moody mesh-gradient fill used wherever a title has no real
/// artwork. The same seed always produces the same art, so a poster looks
/// identical every launch. Dark and low-saturation on purpose — it should read
/// as a considered placeholder, never a rainbow.
struct GeneratedArtwork: View {
    let seed: String

    var body: some View {
        let hash = StableHash.hash(seed)
        let baseHue = Double(hash % 360) / 360.0

        MeshGradient(
            width: 3,
            height: 3,
            points: Self.points(hash),
            colors: Self.colors(baseHue: baseHue, hash: hash)
        )
        .overlay(
            LinearGradient(colors: [.white.opacity(0.06), .clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            RadialGradient(colors: [.clear, .black.opacity(0.28)],
                           center: .center, startRadius: 30, endRadius: 460)
        )
    }

    // MARK: - Deterministic generation

    private static func stream(_ seed: UInt64) -> () -> Double {
        var state = seed == 0 ? 0x1234_5678_9ABC_DEF0 : seed
        return {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 40) / Double(1 << 24)   // 0..<1
        }
    }

    private static func points(_ hash: UInt64) -> [SIMD2<Float>] {
        let r = stream(hash ^ 0xA5A5_A5A5_A5A5_A5A5)
        func f(_ v: Double) -> Float { Float(v) }
        let cx = f(0.5 + (r() - 0.5) * 0.42)
        let cy = f(0.5 + (r() - 0.5) * 0.42)
        return [
            SIMD2<Float>(0, 0),            SIMD2<Float>(0.5, f(r() * 0.18)),     SIMD2<Float>(1, 0),
            SIMD2<Float>(f(r() * 0.18), 0.5), SIMD2<Float>(cx, cy),              SIMD2<Float>(1 - f(r() * 0.18), 0.5),
            SIMD2<Float>(0, 1),            SIMD2<Float>(0.5, 1 - f(r() * 0.18)), SIMD2<Float>(1, 1),
        ]
    }

    private static func colors(baseHue: Double, hash: UInt64) -> [Color] {
        let r = stream(hash ^ 0x9E37_79B9_7F4A_7C15)
        func wrap(_ h: Double) -> Double {
            let m = h.truncatingRemainder(dividingBy: 1.0)
            return m < 0 ? m + 1 : m
        }
        func c(hueShift: Double, sat: Double, bri: Double) -> Color {
            Color(hue: wrap(baseHue + hueShift), saturation: sat, brightness: bri)
        }
        // One warmer accent cell, roughly complementary, keeps posters distinct.
        let accentHue = wrap(baseHue + 0.42 + (r() - 0.5) * 0.1)
        let s = 0.22 + r() * 0.1
        return [
            c(hueShift: -0.02, sat: s, bri: 0.09),
            c(hueShift:  0.03, sat: s + 0.06, bri: 0.15),
            c(hueShift: -0.03, sat: s, bri: 0.08),
            c(hueShift:  0.04, sat: s + 0.04, bri: 0.13),
            Color(hue: accentHue, saturation: s + 0.08, brightness: 0.19),
            c(hueShift: -0.04, sat: s, bri: 0.11),
            c(hueShift: -0.02, sat: s - 0.04, bri: 0.07),
            c(hueShift:  0.02, sat: s + 0.02, bri: 0.12),
            c(hueShift:  0.05, sat: s, bri: 0.09),
        ]
    }
}
