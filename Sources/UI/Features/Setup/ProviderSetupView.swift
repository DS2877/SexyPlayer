import SwiftUI

/// Onboarding + "add another provider" flow. Deliberately hides IPTV jargon:
/// the user picks how they connect, fills a short form, and waits while the
/// library is prepared.
struct ProviderSetupView: View {
    /// When presented from Settings we can be dismissed; at first launch we can't.
    var isDismissable: Bool = false
    var onFinished: (() -> Void)? = nil

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    enum Step: Equatable {
        case choose
        case xtream
        case m3u
        case preparing
        case failed(ProviderError)
    }
    @State private var step: Step = .choose

    // Xtream form
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    // M3U form
    @State private var playlistURL = ""
    @State private var epgURL = ""
    @State private var nickname = ""

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            content
                .frame(maxWidth: 1100)
                .padding(Metrics.screenMargin)
        }
        .onChange(of: env.loadState) { _, state in
            guard step == .preparing else { return }
            switch state {
            case .ready:
                onFinished?()
                if isDismissable { dismiss() }
            case .failed(let error):
                step = .failed(error)
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .choose:      chooser
        case .xtream:      xtreamForm
        case .m3u:         m3uForm
        case .preparing:   PreparingView()
        case .failed(let error):
            ErrorStateView(error: error,
                           onRetry: { step = .choose },
                           onEditProvider: { step = .choose })
        }
    }

    // MARK: Chooser

    private var chooser: some View {
        VStack(alignment: .leading, spacing: Metrics.space4) {
            VStack(alignment: .leading, spacing: Metrics.space1) {
                Text("Add your TV provider").font(.dsHero)
                Text("Connect the service you already subscribe to. SexyPlayer is just the player — it doesn't provide any channels or content.")
                    .font(.dsBody).foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: 800, alignment: .leading)
            }

            HStack(spacing: Metrics.space3) {
                choiceCard(title: "Xtream Codes", subtitle: "Server, username & password", icon: "person.badge.key") {
                    step = .xtream
                }
                choiceCard(title: "M3U Playlist URL", subtitle: "A playlist link (.m3u / .m3u8)", icon: "link") {
                    step = .m3u
                }
                choiceCard(title: "Try the demo", subtitle: "Explore with sample content", icon: "sparkles") {
                    Task { await activate(.demo) }
                }
            }

            if isDismissable {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
            }
        }
    }

    private func choiceCard(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Metrics.space2) {
                Image(systemName: icon).font(.system(size: 44)).foregroundStyle(Palette.accent)
                Spacer(minLength: 0)
                Text(title).font(.dsCardTitle).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(.dsCaption).foregroundStyle(Palette.textTertiary).lineLimit(2)
            }
            .padding(Metrics.space3)
            .frame(width: 320, height: 260, alignment: .leading)
        }
        .buttonStyle(.card)
    }

    // MARK: Xtream form

    private var xtreamForm: some View {
        VStack(alignment: .leading, spacing: Metrics.space3) {
            Text("Xtream Codes").font(.dsTitle)
            Text("Enter the details from your provider. These are stored securely on this Apple TV and only sent to your provider.")
                .font(.dsCaption).foregroundStyle(Palette.textSecondary).frame(maxWidth: 800, alignment: .leading)

            LabeledField("Server URL or host", text: $host, prompt: "http://example.com:8080")
            LabeledField("Username", text: $username, prompt: "username")
            LabeledField("Password", text: $password, prompt: "password", isSecure: true)
            LabeledField("Name (optional)", text: $nickname, prompt: "My Provider")

            HStack(spacing: Metrics.space2) {
                Button("Back") { step = .choose }.buttonStyle(.bordered)
                Button("Connect") { Task { await activate(.xtream) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(host.isEmpty || username.isEmpty || password.isEmpty)
            }
        }
    }

    // MARK: M3U form

    private var m3uForm: some View {
        VStack(alignment: .leading, spacing: Metrics.space3) {
            Text("M3U Playlist").font(.dsTitle)
            LabeledField("Playlist URL", text: $playlistURL, prompt: "https://…/get.php?…")
            LabeledField("EPG / TV guide URL (optional)", text: $epgURL, prompt: "https://…/xmltv.php?…")
            LabeledField("Name (optional)", text: $nickname, prompt: "My Playlist")

            HStack(spacing: Metrics.space2) {
                Button("Back") { step = .choose }.buttonStyle(.bordered)
                Button("Connect") { Task { await activate(.m3u) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(playlistURL.isEmpty)
            }
        }
    }

    // MARK: Actions

    private enum Kind { case demo, xtream, m3u }

    private func activate(_ kind: Kind) async {
        let config: ProviderConfiguration
        switch kind {
        case .demo:
            config = ProviderStore.demoConfiguration
        case .xtream:
            config = env.providers.addXtream(host: host, username: username, password: password, displayName: nickname)
        case .m3u:
            config = env.providers.addM3U(playlistURL: playlistURL,
                                          epgURL: epgURL.isEmpty ? nil : epgURL,
                                          displayName: nickname)
        }
        step = .preparing
        await env.activate(config)
    }
}

/// Focusable labelled text field styled for tvOS.
struct LabeledField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var isSecure: Bool = false

    init(_ label: String, text: Binding<String>, prompt: String = "", isSecure: Bool = false) {
        self.label = label
        self._text = text
        self.prompt = prompt
        self.isSecure = isSecure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.dsCaption).foregroundStyle(Palette.textTertiary)
            Group {
                if isSecure {
                    SecureField(prompt, text: $text)
                } else {
                    TextField(prompt, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.dsBody)
            .padding(Metrics.space2)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius))
            .frame(maxWidth: 760)
        }
    }
}

struct PreparingView: View {
    @State private var dots = 0

    var body: some View {
        VStack(spacing: Metrics.space3) {
            ProgressView().controlSize(.large).tint(Palette.accent)
            Text("Preparing your library" + String(repeating: ".", count: dots))
                .font(.dsTitle)
                .animation(.none, value: dots)
            Text("Fetching channels, movies and series, and tidying up the messy bits.")
                .font(.dsBody).foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(450))
                dots = (dots + 1) % 4
            }
        }
    }
}
