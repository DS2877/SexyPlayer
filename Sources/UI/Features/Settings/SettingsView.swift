import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showAddProvider = false
    @State private var showPersonalize = false
    @State private var showAIKey = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.space5) {
                    Text("Settings").font(.dsTitle)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Metrics.space4)

                    providersSection
                    personalizeSection
                    aiSection
                    aboutSection
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, Metrics.space7)
                .frame(maxWidth: 1200, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .appThemeBackground()
        }
        .fullScreenCover(isPresented: $showAddProvider) {
            ProviderSetupView(isDismissable: true)
                .environment(env)
        }
        .fullScreenCover(isPresented: $showPersonalize) {
            PersonalizeView(mode: .settings)
                .environment(env)
        }
        .fullScreenCover(isPresented: $showAIKey) {
            AIKeyView().environment(env)
        }
    }

    private var personalizeSection: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            SectionHeader("Personalize", subtitle: "Languages, subtitles, adult filter, Home rows")
            Button {
                showPersonalize = true
            } label: {
                HStack {
                    Label("Edit your preferences", systemImage: "slider.horizontal.3")
                        .font(.dsBody)
                    Spacer()
                    Text(preferenceSummary).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                }
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    private var preferenceSummary: String {
        let p = env.preferences.preferences
        var parts: [String] = []
        if !p.preferredAudioLanguages.isEmpty {
            parts.append(p.preferredAudioLanguages.map(\.displayName).joined(separator: ", "))
        }
        if let s = p.preferredSubtitleLanguage { parts.append("\(s.displayName) subs") }
        if p.hideAdultContent { parts.append("Adult hidden") }
        if env.parental.isEnabled { parts.append("PIN on") }
        return parts.isEmpty ? "Not set" : parts.joined(separator: " · ")
    }

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            SectionHeader("Your Provider")

            ForEach(env.providers.allConfigurations) { config in
                HStack(spacing: Metrics.space2) {
                    Image(systemName: icon(for: config.kind))
                        .font(.system(size: 28)).foregroundStyle(Palette.accent)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.displayName).font(.dsCardTitle)
                        Text(subtitle(for: config)).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                    if config.id == env.providers.activeID {
                        Text("Active").font(.dsTag).foregroundStyle(Palette.accent)
                    } else {
                        Button("Use") { Task { await env.activate(config) } }
                            .buttonStyle(.bordered)
                    }
                    if config.kind != .mock {
                        Button(role: .destructive) {
                            Task { await env.removeProvider(config.id) }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Remove \(config.displayName)")
                    }
                }
                .padding(Metrics.space2)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius))
            }

            HStack(spacing: Metrics.space2) {
                Button {
                    showAddProvider = true
                } label: {
                    Label("Add a provider", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await env.refreshLibrary() }
                } label: {
                    Label(env.isRefreshing ? "Refreshing…" : "Refresh library",
                          systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(env.isRefreshing || env.activeProvider == nil)
            }
            .padding(.top, Metrics.space1)
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            SectionHeader("AI Search", subtitle: "Natural-language search understanding")
            Toggle(isOn: Binding(
                get: { env.preferences.preferences.aiAssistedSearch },
                set: { on in
                    env.preferences.update { $0.aiAssistedSearch = on }
                    Task { await env.applyPreferences() }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use AI-assisted understanding").font(.dsBody)
                    Text("When on, ambiguous searches send only your words and the list of genres/languages in your library — never your provider details, stream links, or what you watch.")
                        .font(.dsCaption).foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: 900, alignment: .leading)
                }
            }
            .padding(Metrics.space2)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius))

            if env.preferences.preferences.aiAssistedSearch {
                Button {
                    showAIKey = true
                } label: {
                    HStack {
                        Label(env.hasAIKey ? "Claude key connected" : "Connect a Claude API key",
                              systemImage: env.hasAIKey ? "checkmark.seal" : "key")
                            .font(.dsBody)
                        Spacer()
                        Text(env.hasAIKey ? "Change" : "Add").font(.dsCaption).foregroundStyle(Palette.textTertiary)
                    }
                }
                .buttonStyle(RowButtonStyle())

                Text("Without a key, AI-assisted search quietly falls back to on-device understanding.")
                    .font(.dsCaption).foregroundStyle(Palette.textTertiary)
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Metrics.space1) {
            SectionHeader("About")
            Text("SexyPlayer is a player only. It does not provide, sell, host, or recommend any channels, streams, or media. You connect a provider you already subscribe to.")
                .font(.dsCaption).foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: 1000, alignment: .leading)
        }
    }

    private func icon(for kind: ProviderKind) -> String {
        switch kind {
        case .mock:   return "sparkles"
        case .xtream: return "person.badge.key"
        case .m3u:    return "link"
        }
    }

    private func subtitle(for config: ProviderConfiguration) -> String {
        switch config.kind {
        case .mock:   return "Sample content for exploring the app"
        case .xtream: return [config.xtreamUsername, config.xtreamHost].compactMap { $0 }.joined(separator: " · ")
        case .m3u:    return config.m3uHostForDisplay ?? "Playlist"
        }
    }
}
