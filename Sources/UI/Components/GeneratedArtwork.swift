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
            LinearGradient(colors: [.white.opacity(0.05), .clear, .black.opacity(0.22)],
                           startPoint: .top, endPoint: .bottom)
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
        // Edges stay pinned to the frame so the fill never visibly warps; only
        // the centre control point drifts, which just shifts the colour flow.
        let cx = Float(0.5 + (r() - 0.5) * 0.22)
        let cy = Float(0.5 + (r() - 0.5) * 0.22)
        return [
            SIMD2<Float>(0, 0), SIMD2<Float>(0.5, 0),   SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5), SIMD2<Float>(cx, cy), SIMD2<Float>(1, 0.5),
            SIMD2<Float>(0, 1), SIMD2<Float>(0.5, 1),   SIMD2<Float>(1, 1),
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
        let s = 0.20 + r() * 0.08
        return [
            c(hueShift: -0.02, sat: s, bri: 0.105),
            c(hueShift:  0.03, sat: s + 0.05, bri: 0.135),
            c(hueShift: -0.03, sat: s, bri: 0.10),
            c(hueShift:  0.04, sat: s + 0.03, bri: 0.125),
            Color(hue: accentHue, saturation: s + 0.07, brightness: 0.155),
            c(hueShift: -0.04, sat: s, bri: 0.115),
            c(hueShift: -0.02, sat: s - 0.03, bri: 0.095),
            c(hueShift:  0.02, sat: s + 0.02, bri: 0.12),
            c(hueShift:  0.05, sat: s, bri: 0.105),
        ]
    }
}
