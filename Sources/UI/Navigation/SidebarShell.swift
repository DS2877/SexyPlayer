import SwiftUI

/// The app's main navigation — a fixed left sidebar (premium tvOS pattern, à la
/// Plex / Infuse / the Apple TV app) with the selected section on the right.
/// Non-blocking: if the library is still importing, a slim status pill appears
/// over the content instead of locking the user out.
struct SidebarShell: View {
    @Environment(AppEnvironment.self) private var env

    enum Section: String, CaseIterable, Identifiable {
        case home, search, liveTV, guide, movies, series, favorites, history, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: return "Home"
            case .search: return "Search"
            case .liveTV: return "Live TV"
            case .guide: return "Guide"
            case .movies: return "Movies"
            case .series: return "Series"
            case .favorites: return "Favorites"
            case .history: return "History"
            case .settings: return "Settings"
            }
        }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .liveTV: return "tv.fill"
            case .guide: return "rectangle.grid.1x2.fill"
            case .movies: return "film.fill"
            case .series: return "rectangle.stack.fill"
            case .favorites: return "heart.fill"
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape.fill"
            }
        }
    }

    private static let primary: [Section] = [.home, .search, .liveTV, .guide, .movies, .series, .favorites, .history]

    @State private var selection: Section = .home

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) { LibraryStatusPill() }
        }
        .background(Palette.canvas.ignoresSafeArea())
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Metrics.space1) {
            HStack(spacing: Metrics.space1) {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.canvas)
                    .frame(width: 44, height: 44)
                    .background(Palette.textPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Aeria+").font(.dsCardTitle).foregroundStyle(Palette.textPrimary)
            }
            .padding(.horizontal, Metrics.space2)
            .padding(.top, Metrics.space4)
            .padding(.bottom, Metrics.space3)
            .accessibilityHidden(true)

            ForEach(Self.primary) { item in
                SidebarItem(section: item, isSelected: selection == item) { select(item) }
            }

            Spacer(minLength: 0)

            SidebarItem(section: .settings, isSelected: selection == .settings) { select(.settings) }
                .padding(.bottom, Metrics.space4)
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.surface.opacity(0.5).ignoresSafeArea())
        .focusSection()
    }

    private func select(_ item: Section) {
        selection = item
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home:      HomeView()
        case .search:    SearchView()
        case .liveTV:    LiveTVBrowseView()
        case .guide:     GuideView()
        case .movies:    VODBrowseView(kind: .movies)
        case .series:    VODBrowseView(kind: .series)
        case .favorites: FavoritesView()
        case .history:   HistoryView()
        case .settings:  SettingsView()
        }
    }
}

private struct SidebarItem: View {
    let section: SidebarShell.Section
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.space2) {
                Image(systemName: section.icon)
                    .font(.system(size: 24))
                    .frame(width: 32)
                Text(section.title).font(.dsBody)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(SidebarButtonStyle(isSelected: isSelected))
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        SidebarButtonBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct SidebarButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .padding(.horizontal, Metrics.space2)
            .padding(.vertical, Metrics.space1 + 5)
            .foregroundStyle(textColor)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill)
            )
            .overlay(alignment: .leading) {
                // Slim brand marker on the active section (not while focused).
                if isSelected && !isFocused {
                    Capsule().fill(Palette.accent)
                        .frame(width: 4, height: 22)
                        .offset(x: -2)
                }
            }
            .padding(.horizontal, Metrics.space2)
            .scaleEffect(isFocused ? 1.03 : 1)
            .shadow(color: .black.opacity(isFocused ? 0.35 : 0), radius: isFocused ? 20 : 0, y: isFocused ? 10 : 0)
            .animation(Metrics.focusAnimation, value: isFocused)
    }

    private var textColor: Color {
        if isFocused { return Palette.canvas }              // dark label on the bright highlight
        if isSelected { return Palette.textPrimary }
        return Palette.textSecondary
    }

    private var fill: Color {
        if isFocused { return Palette.focusFill }
        if isSelected { return .white.opacity(0.07) }
        return .clear
    }
}

/// Slim non-blocking status shown over any screen while the library imports or
/// if the last refresh failed.
private struct LibraryStatusPill: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            switch env.loadState {
            case .loading:
                pill {
                    HStack(spacing: Metrics.space1) {
                        ProgressView().controlSize(.small).tint(Palette.textPrimary)
                        Text(env.reachedPhases.contains(.guide)
                             ? "Organising your library…"
                             : "Importing your library…")
                    }
                }
            case .failed(let error):
                pill {
                    HStack(spacing: Metrics.space1) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error.title)
                        Button("Retry") { Task { await env.bootstrap(forceReload: true) } }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            case .idle, .ready:
                EmptyView()
            }
        }
        .padding(.top, Metrics.space2)
        .animation(.easeInOut, value: statusKey)
    }

    private var statusKey: Int {
        switch env.loadState {
        case .idle: return 0
        case .loading: return 1
        case .ready: return 2
        case .failed: return 3
        }
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.dsCaption)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Metrics.space2)
            .padding(.vertical, Metrics.space1)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.hairline))
    }
}
