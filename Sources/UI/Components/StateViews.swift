import SwiftUI

/// Friendly empty state — never a dead end.
public struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    public init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Metrics.space3) {
            Image(systemName: icon)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Palette.textTertiary)
            Text(title).font(.dsTitle)
            Text(message)
                .font(.dsBody)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 720)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, Metrics.space2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Metrics.space6)
    }
}

/// Error state built from a `ProviderError` — shows the calm message plus its
/// recovery actions. Raw errors never reach here.
public struct ErrorStateView: View {
    let error: ProviderError
    let onRetry: (() -> Void)?
    let onEditProvider: (() -> Void)?

    public init(error: ProviderError, onRetry: (() -> Void)? = nil, onEditProvider: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
        self.onEditProvider = onEditProvider
    }

    public var body: some View {
        VStack(spacing: Metrics.space3) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Palette.textTertiary)
            Text(error.title).font(.dsTitle)
            Text(error.message)
                .font(.dsBody)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 720)

            HStack(spacing: Metrics.space2) {
                ForEach(Array(error.recoveryActions.enumerated()), id: \.offset) { _, recovery in
                    Button(recovery.label) {
                        switch recovery {
                        case .retry, .checkConnection: onRetry?()
                        case .editProvider: onEditProvider?()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, Metrics.space2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Metrics.space6)
    }
}

/// A single placeholder block with a moving highlight sweep. The building
/// block for every loading skeleton in the app.
public struct SkeletonBox: View {
    var cornerRadius: CGFloat
    @State private var sweep: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(cornerRadius: CGFloat = Metrics.cardCornerRadius) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Palette.surface)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Palette.textPrimary.opacity(0.06), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.55)
                    .offset(x: sweep * geo.size.width * 1.4)
                    .opacity(reduceMotion ? 0 : 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    sweep = 1
                }
            }
            .accessibilityHidden(true)
    }
}

/// Placeholder channel-strip list shown while the TV Guide loads — mirrors the
/// Guide's own row layout (label + a strip of programme cells) rather than the
/// poster grid.
public struct SkeletonGuide: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space3) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBox(cornerRadius: 6)
                        .frame(width: 180, height: 20)
                        .padding(.horizontal, Metrics.screenMargin)
                    HStack(spacing: Metrics.space1) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonBox().frame(width: 248, height: 118)
                        }
                    }
                    .padding(.horizontal, Metrics.screenMargin)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Metrics.space5)
        .accessibilityHidden(true)
    }
}

/// Placeholder poster rail shown while a catalog loads.
public struct SkeletonShelf: View {
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    public init(cardWidth: CGFloat = Metrics.posterWidth, cardHeight: CGFloat = Metrics.posterHeight) {
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            SkeletonBox(cornerRadius: 6)
                .frame(width: 260, height: 26)
                .padding(.horizontal, Metrics.screenMargin)
            HStack(spacing: Metrics.cardSpacing) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonBox().frame(width: cardWidth, height: cardHeight)
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
        }
        .accessibilityHidden(true)
    }
}
