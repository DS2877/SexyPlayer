import SwiftUI

/// Lets the user shape the experience — languages, subtitles, adult filter, and
/// which Home rows appear. Used as the last onboarding step and re-openable from
/// Settings.
struct PersonalizeView: View {
    enum Mode { case onboarding, settings }
    var mode: Mode = .settings
    var onDone: () -> Void = {}

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var working = UserPreferences()

    private var languages: [Language] {
        let all = env.vocabulary.audioLanguages + env.vocabulary.subtitleLanguages
        return Array(Set(all)).sorted()
    }
    private var subtitleLanguages: [Language] {
        env.vocabulary.subtitleLanguages.isEmpty ? languages : env.vocabulary.subtitleLanguages.sorted()
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.space5) {
                    header
                    languageSection
                    if !subtitleLanguages.isEmpty { subtitleSection }
                    adultSection
                    homeRowsSection
                    footer
                }
                .padding(Metrics.screenMargin)
                .frame(maxWidth: 1100, alignment: .leading)
            }
        }
        .onAppear { working = env.preferences.preferences }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.space1) {
            Text(mode == .onboarding ? "Make it yours" : "Personalize")
                .font(.dsHero)
            Text("A few choices so the app shows you what matters. You can change all of this later in Settings.")
                .font(.dsBody).foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var languageSection: some View {
        section("Your languages", "Content in these languages gets its own row and is prioritised.") {
            if languages.isEmpty {
                Text("We'll detect languages once your library is fully scanned.")
                    .font(.dsCaption).foregroundStyle(Palette.textTertiary)
            } else {
                chipFlow(languages) { lang in
                    working.preferredAudioLanguages.contains(lang)
                } toggle: { lang in
                    toggleInArray(\.preferredAudioLanguages, lang)
                }
            }
        }
    }

    private var subtitleSection: some View {
        section("Subtitle language", "For the \u{201C}With Your Subtitles\u{201D} row and default subtitle track.") {
            chipFlow(subtitleLanguages) { lang in
                working.preferredSubtitleLanguage == lang
            } toggle: { lang in
                working.preferredSubtitleLanguage = (working.preferredSubtitleLanguage == lang) ? nil : lang
            }
        }
    }

    private var adultSection: some View {
        section("Adult content", nil) {
            Toggle(isOn: $working.hideAdultContent) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hide adult categories").font(.dsBody)
                    Text("Keeps adult-flagged channels and titles out of Home, browsing and search.")
                        .font(.dsCaption).foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(Metrics.space2)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius))
        }
    }

    private var homeRowsSection: some View {
        section("Home screen rows", "Turn rows on or off. They appear in this order.") {
            VStack(spacing: Metrics.space1) {
                ForEach(HomeRowKind.allCases) { row in
                    Button {
                        toggleHomeRow(row)
                    } label: {
                        HStack(spacing: Metrics.space2) {
                            Image(systemName: working.homeRows.contains(row) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(working.homeRows.contains(row) ? Palette.accent : Palette.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).font(.dsBody)
                                Text(row.explanation).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(Metrics.space2)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Metrics.space2) {
            if mode == .settings {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
            }
            Button(mode == .onboarding ? "Finish setup" : "Save") {
                var next = working
                if mode == .onboarding { next.hasOnboarded = true }
                env.preferences.update { $0 = next }
                Task { await env.applyPreferences() }
                onDone()
                if mode == .settings { dismiss() }
            }
            .buttonStyle(.borderedProminent)
            .font(.dsCardTitle)
        }
        .padding(.top, Metrics.space2)
    }

    // MARK: helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, _ note: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Text(title).font(.dsSectionHeader)
            if let note {
                Text(note).font(.dsCaption).foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: 820, alignment: .leading)
            }
            content()
        }
    }

    private func chipFlow(_ langs: [Language], isOn: @escaping (Language) -> Bool, toggle: @escaping (Language) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metrics.space1) {
                ForEach(langs, id: \.self) { lang in
                    FilterChip(label: lang.displayName, isSelected: isOn(lang)) { toggle(lang) }
                }
            }
        }
        .focusSection()
    }

    private func toggleInArray(_ keyPath: WritableKeyPath<UserPreferences, [Language]>, _ value: Language) {
        if let idx = working[keyPath: keyPath].firstIndex(of: value) {
            working[keyPath: keyPath].remove(at: idx)
        } else {
            working[keyPath: keyPath].append(value)
        }
    }

    private func toggleHomeRow(_ row: HomeRowKind) {
        if let idx = working.homeRows.firstIndex(of: row) {
            working.homeRows.remove(at: idx)
        } else {
            // Re-insert in canonical order.
            working.homeRows = HomeRowKind.allCases.filter { working.homeRows.contains($0) || $0 == row }
        }
    }
}
