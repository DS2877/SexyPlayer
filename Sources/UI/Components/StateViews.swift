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

/// Shimmer placeholder rail shown while a catalog loads.
public struct SkeletonShelf: View {
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @State private var shimmer = false

    public init(cardWidth: CGFloat = Metrics.posterWidth, cardHeight: CGFloat = Metrics.posterHeight) {
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            RoundedRectangle(cornerRadius: 6).fill(Palette.surface)
                .frame(width: 280, height: 30)
                .padding(.horizontal, Metrics.screenMargin)
            HStack(spacing: Metrics.cardSpacing) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                        .fill(Palette.surface)
                        .frame(width: cardWidth, height: cardHeight)
                        .opacity(shimmer ? 0.45 : 0.85)
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .accessibilityHidden(true)
    }
}
