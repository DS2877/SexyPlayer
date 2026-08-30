import SwiftUI

/// A 16:9 card for a live channel — logo (or a quiet monogram), the channel
/// name, and the current programme when EPG data is available.
public struct ChannelCard: View {
    let name: String
    let logoURL: URL?
    let nowTitle: String?
    let nextTitle: String?
    let quality: VideoQuality
    let nowProgress: Double?
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    public init(
        name: String,
        logoURL: URL? = nil,
        nowTitle: String? = nil,
        nextTitle: String? = nil,
        quality: VideoQuality = .unknown,
        nowProgress: Double? = nil,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.logoURL = logoURL
        self.nowTitle = nowTitle
        self.nextTitle = nextTitle
        self.quality = quality
        self.nowProgress = nowProgress
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Metrics.space1) {
                ZStack {
                    Palette.placeholderGradient(for: name)

                    if let logoURL {
                        AsyncImage(url: logoURL) { $0.resizable().scaledToFit().padding(Metrics.space3) }
                            placeholder: { monogram }
                    } else {
                        monogram
                    }

                    if quality > .unknown {
                        VStack {
                            HStack {
                                Spacer()
                                QualityBadge(quality: quality).padding(Metrics.space1)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: Metrics.wideCardWidth, height: Metrics.wideCardHeight)
                .overlay(alignment: .bottom) {
                    if let nowProgress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(.white.opacity(0.18))
                                Rectangle().fill(Palette.accent)
                                    .frame(width: geo.size.width * Swift.min(1, Swift.max(0, nowProgress)))
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
                .shadow(color: .black.opacity(isFocused ? 0.5 : 0),
                        radius: isFocused ? 26 : 0, y: isFocused ? 16 : 0)

                Text(name)
                    .font(.dsCardTitle)
                    .foregroundStyle(isFocused ? Palette.textPrimary : Palette.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 4)

                metadataLine
                    .frame(height: 22, alignment: .leading)
            }
            .frame(width: Metrics.wideCardWidth, alignment: .leading)
        }
        .buttonStyle(.card)
        .accessibilityLabel(Text(nowTitle.map { "\(name), now playing \($0)" } ?? name))
    }

    @ViewBuilder
    private var metadataLine: some View {
        if let nowTitle {
            HStack(spacing: 7) {
                Circle().fill(Palette.liveDot).frame(width: 7, height: 7)
                Text(nowTitle)
                    .font(.dsCaption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
        } else {
            Text("Live")
                .font(.dsCaption)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var monogram: some View {
        Text(name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased())
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.32))
    }
}
