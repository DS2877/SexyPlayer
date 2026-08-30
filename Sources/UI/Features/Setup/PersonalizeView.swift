import SwiftUI

/// Lets the user shape the experience — languages, subtitles, content filters,
/// and which Home rows appear. Last onboarding step and re-openable from Settings.
struct PersonalizeView: View {
    enum Mode { case onboarding, settings }
    var mode: Mode = .settings
    var onDone: () -> Void = {}

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var working = UserPreferences()

    private var audioLanguages: [Language] {
        let all = env.vocabulary.audioLanguages + env.vocabulary.subtitleLanguages
        return Array(Set(all)).sorted()
    }
    private var subtitleLanguages: [Language] {
        env.vocabulary.subtitleLanguages.isEmpty ? audioLanguages : env.vocabulary.subtitleLanguages.sorted()
    }

    private let choiceColumns = [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: Metrics.space2)]

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.space7) {
                    header

                    if audioLanguages.isEmpty {
                        PersonalizeSection("Your languages", nil) {
                            Text("We'll detect the languages in your library as it finishes scanning. You can set these in Settings any time.")
                                .font(.dsBody).foregroundStyle(Palette.textSecondary)
                        }
                    } else {
                        PersonalizeSection("Your languages", "Content in these languages gets its own row on Home and is prioritised everywhere.") {
                            LazyVGrid(columns: choiceColumns, alignment: .leading, spacing: Metrics.space2) {
                                ForEach(audioLanguages, id: \.self) { lang in
                                    ChoiceCard(title: lang.displayName,
                                               isSelected: working.preferredAudioLanguages.contains(lang)) {
                                        toggleArray(\.preferredAudioLanguages, lang)
                                    }
                                }
                            }
                        }
                    }

                    if !subtitleLanguages.isEmpty {
                        PersonalizeSection("Subtitle language", "Used for the “With Your Subtitles” row and as the default subtitle track.") {
                            LazyVGrid(columns: choiceColumns, alignment: .leading, spacing: Metrics.space2) {
                                ForEach(subtitleLanguages, id: \.self) { lang in
                                    ChoiceCard(title: lang.displayName,
                                               isSelected: working.preferredSubtitleLanguage == lang) {
                                        working.preferredSubtitleLanguage =
                                            (working.preferredSubtitleLanguage == lang) ? nil : lang
                                    }
                                }
                            }
                        }
                    }

                    PersonalizeSection("Playback & content", nil) {
                        VStack(spacing: Metrics.space2) {
                            OptionRow(icon: "eye.slash",
                                      title: "Hide adult categories",
                                      note: "Keeps adult-flagged channels and titles out of Home, browsing and search.",
                                      isOn: working.hideAdultContent) { working.hideAdultContent.toggle() }
                            OptionRow(icon: "play.rectangle.on.rectangle",
                                      title: "Autoplay next episode",
                                      note: "When an episode finishes, the next one starts automatically.",
                                      isOn: working.autoPlayNextEpisode) { working.autoPlayNextEpisode.toggle() }
                            OptionRow(icon: "sparkles",
                                      title: "AI-assisted search",
                                      note: "For vague searches, sends only your words and your library's genre/language list — never credentials, links, or history.",
                                      isOn: working.aiAssistedSearch) { working.aiAssistedSearch.toggle() }
                        }
                    }

                    PersonalizeSection("Home screen rows", "Turn rows on or off — they appear in this order.") {
                        VStack(spacing: Metrics.space2) {
                            ForEach(HomeRowKind.allCases) { row in
                                OptionRow(icon: nil,
                                          title: row.title,
                                          note: row.explanation,
                                          isOn: working.homeRows.contains(row)) { toggleHomeRow(row) }
                            }
                        }
                    }

                    footer
                }
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.vertical, Metrics.space6)
            }
        }
        .onAppear { working = env.preferences.preferences }
    }

    // MARK: - Header / footer

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.space1) {
            Text(mode == .onboarding ? "Make it yours" : "Personalize")
                .font(.dsHero)
            Text("A few quick choices so the app shows you what matters. Everything here can be changed later in Settings.")
                .font(.dsBody)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var footer: some View {
        HStack(spacing: Metrics.space2) {
            if mode == .settings {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .font(.dsCardTitle)
            }
            Button {
                var next = working
                if mode == .onboarding { next.hasOnboarded = true }
                env.preferences.update { $0 = next }
                Task { await env.applyPreferences() }
                onDone()
                if mode == .settings { dismiss() }
            } label: {
                Text(mode == .onboarding ? "Finish setup" : "Save changes")
                    .font(.dsCardTitle)
                    .padding(.horizontal, Metrics.space4)
                    .padding(.vertical, Metrics.space1)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, Metrics.space3)
    }

    // MARK: - Mutation helpers

    private func toggleArray(_ keyPath: WritableKeyPath<UserPreferences, [Language]>, _ value: Language) {
        if let idx = working[keyPath: keyPath].firstIndex(of: value) {
            working[keyPath: keyPath].remove(at: idx)
        } else {
            working[keyPath: keyPath].append(value)
        }
    }

    private func toggleHomeRow(_ row: HomeRowKind) {
        if working.homeRows.contains(row) {
            working.homeRows.removeAll { $0 == row }
        } else {
            working.homeRows = HomeRowKind.allCases.filter { working.homeRows.contains($0) || $0 == row }
        }
    }
}

// MARK: - Section wrapper

private struct PersonalizeSection<Content: View>: View {
    let title: String
    let note: String?
    let content: () -> Content

    init(_ title: String, _ note: String?, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.note = note
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space3) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.dsSectionHeader).foregroundStyle(Palette.textPrimary)
                if let note {
                    Text(note).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Rectangle().fill(Palette.hairline).frame(height: 1).padding(.top, 4)
            }
            content()
        }
    }
}

// MARK: - Reusable choices

/// A compact multi/single-select card (languages).
private struct ChoiceCard: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.space1) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Palette.accent : Palette.textTertiary)
                Text(title)
                    .font(.dsCardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.space2)
            .frame(height: 84)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.card)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A full-width on/off row for a preference or a Home row.
private struct OptionRow: View {
    let icon: String?
    let title: String
    let note: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.space3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundStyle(isOn ? Palette.accent : Palette.textTertiary)
                        .frame(width: 40)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.dsCardTitle).foregroundStyle(Palette.textPrimary)
                    Text(note).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Metrics.space2)
                StatePill(isOn: isOn)
            }
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

private struct StatePill: View {
    let isOn: Bool
    var body: some View {
        Text(isOn ? "On" : "Off")
            .font(.dsTag)
            .foregroundStyle(isOn ? Palette.canvas : Palette.textSecondary)
            .padding(.horizontal, Metrics.space2)
            .padding(.vertical, 8)
            .background(isOn ? Palette.accent : Palette.surfaceElevated, in: Capsule())
    }
}
