import SwiftUI

/// Shown by a feature screen when it has nothing to display *because the library
/// is still importing* — as opposed to a genuine "no results" state.
struct LibraryLoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: Metrics.space2) {
            ProgressView().controlSize(.large).tint(Palette.accent)
            Text("Your library is still loading")
                .font(.dsTitle)
            Text("This screen will fill in as soon as it's ready.")
                .font(.dsBody).foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Metrics.space6)
    }
}

extension AppEnvironment.LoadState {
    var isImporting: Bool { if case .loading = self { return true } else { return false } }
}
