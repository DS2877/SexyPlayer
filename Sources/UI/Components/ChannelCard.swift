import SwiftUI

/// A 16:9 card for a live channel, showing the logo/name plus the current
/// programme when EPG data is available.
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
                            placeholder: { channelInitials }
                    } else {
                        channelInitials
                    }
                    VStack {
                        HStack {
                            Spacer()
                            QualityBadge(quality: quality).padding(Metrics.space1)
                        }
                        Spacer()
                    }
                }
                .frame(width: Metrics.wideCardWidth, height: Metrics.wideCardHeight)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))

                Text(name)
                    .font(.dsCardTitle)
                    .foregroundStyle(isFocused ? Palette.textPrimary : Palette.textSecondary)
                    .lineLimit(1)

                if let nowTitle {
                    HStack(spacing: 6) {
                        Circle().fill(Palette.liveDot).frame(width: 8, height: 8)
                        Text(nowTitle).font(.dsCaption).foregroundStyle(Palette.textSecondary).lineLimit(1)
                    }
                    if let nowProgress {
                        ProgressView(value: min(1, max(0, nowProgress)))
                            .tint(Palette.accent)
                            .frame(width: Metrics.wideCardWidth)
                    }
                } else {
                    Text("No guide data")
                        .font(.dsCaption).foregroundStyle(Palette.textTertiary)
                }
            }
            .frame(width: Metrics.wideCardWidth, alignment: .leading)
        }
        .buttonStyle(.card)
        .accessibilityLabel(Text(nowTitle.map { "\(name), now playing \($0)" } ?? name))
    }

    private var channelInitials: some View {
        Text(name.split(separator: " ").compactMap(\.first).prefix(3).map(String.init).joined())
            .font(.system(size: 40, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
    }
}
