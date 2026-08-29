import SwiftUI

public struct QualityBadge: View {
    let quality: VideoQuality
    public init(quality: VideoQuality) { self.quality = quality }

    public var body: some View {
        if quality > .unknown {
            Text(quality.shortLabel)
                .font(.dsTag)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairline))
        }
    }
}

public struct LiveBadge: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Palette.liveDot).frame(width: 10, height: 10)
            Text("LIVE").font(.dsTag)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

public struct MetadataLine: View {
    let parts: [String]
    public init(_ parts: [String?]) { self.parts = parts.compactMap { $0 }.filter { !$0.isEmpty } }

    public var body: some View {
        Text(parts.joined(separator: "  ·  "))
            .font(.dsCaption)
            .foregroundStyle(Palette.textSecondary)
            .lineLimit(1)
    }
}
