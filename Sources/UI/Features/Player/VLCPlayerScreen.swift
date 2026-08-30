import SwiftUI
import UIKit

/// Full-screen VLC playback with a lightweight custom transport (VLC has no
/// native tvOS player UI). Siri Remote: Play/Pause toggles, left/right seek
/// ±10s, up opens tracks, Menu exits.
struct VLCPlayerScreen: View {
    let item: PlaybackItem
    var preferredAudio: [Language] = []
    var preferredSubtitle: Language? = nil
    let onProgress: @MainActor (CatalogID, ContentKind, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: VLCPlayerModel?
    @State private var controlsVisible = true
    @State private var showTracks = false
    @State private var hideWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let model {
                VLCVideoView(model: model).ignoresSafeArea()

                if case .failed(let error) = model.state {
                    VStack(spacing: Metrics.space3) {
                        ErrorStateView(error: error, onRetry: nil, onEditProvider: nil)
                        Button("Close") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.96))
                } else {
                    if model.state == .loading {
                        ProgressView().controlSize(.large).tint(.white)
                    }
                    if controlsVisible {
                        controls(model).transition(.opacity)
                    }
                }
            }
        }
        .focusable()
        .onPlayPauseCommand { model?.togglePlayPause(); flashControls() }
        .onMoveCommand { direction in
            switch direction {
            case .left:  model?.seek(by: -10); flashControls()
            case .right: model?.seek(by: 10); flashControls()
            case .up:    if hasTracks { showTracks = true }
            default:     break
            }
        }
        .onExitCommand { dismiss() }
        .animation(.easeInOut(duration: 0.2), value: controlsVisible)
        .fullScreenCover(isPresented: $showTracks) {
            if let model { VLCTrackSheet(model: model) }
        }
        .onAppear {
            let m = VLCPlayerModel(item: item,
                                   preferredAudio: preferredAudio,
                                   preferredSubtitle: preferredSubtitle) { played, position, duration in
                onProgress(played.id, played.kind, position, duration)
            }
            m.onFinished = { dismiss() }
            model = m
            flashControls()
        }
        .onDisappear {
            hideWorkItem?.cancel()
            model?.teardown()
        }
    }

    private var hasTracks: Bool {
        (model?.subtitleTracks.count ?? 0) > 1 || (model?.audioTracks.count ?? 0) > 1
    }

    private func flashControls() {
        controlsVisible = true
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { controlsVisible = false }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    @ViewBuilder
    private func controls(_ model: VLCPlayerModel) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: Metrics.space2) {
                Text(item.title).font(.dsCardTitle).foregroundStyle(.white)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.dsCaption).foregroundStyle(.white.opacity(0.7))
                }

                if model.duration > 0 {
                    ProgressView(value: model.position, total: model.duration).tint(Palette.accent)
                    HStack {
                        Text(timecode(model.position)).font(.dsCaption).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(timecode(model.duration)).font(.dsCaption).foregroundStyle(.white.opacity(0.5))
                    }
                } else if item.isLive {
                    Text("LIVE").font(.dsTag).foregroundStyle(Palette.accent)
                }

                Text(hasTracks
                     ? "‹ ›  seek 10s      ▮▮  play/pause      ▲  audio & subtitles      Menu  exit"
                     : "‹ ›  seek 10s      ▮▮  play/pause      Menu  exit")
                    .font(.dsCaption).foregroundStyle(.white.opacity(0.45))
                    .padding(.top, Metrics.space1)
            }
            .padding(Metrics.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func timecode(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Subtitle + audio track picker over the (still playing) video.
private struct VLCTrackSheet: View {
    @Bindable var model: VLCPlayerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.canvas.opacity(0.96).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.space5) {
                    if model.audioTracks.count > 1 {
                        section("Audio", tracks: model.audioTracks, current: model.currentAudioID) {
                            model.selectAudio($0); dismiss()
                        }
                    }
                    if model.subtitleTracks.count > 1 {
                        section("Subtitles", tracks: model.subtitleTracks, current: model.currentSubtitleID) {
                            model.selectSubtitle($0); dismiss()
                        }
                    }
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.vertical, Metrics.space6)
            }
        }
        .onExitCommand { dismiss() }
    }

    @ViewBuilder
    private func section(_ title: String, tracks: [VLCPlayerModel.Track], current: Int,
                         onPick: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Text(title).font(.dsSectionHeader).foregroundStyle(Palette.textPrimary)
            ForEach(tracks) { track in
                Button { onPick(track.id) } label: {
                    HStack {
                        Image(systemName: track.id == current ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(track.id == current ? Palette.accent : Palette.textTertiary)
                        Text(track.name).font(.dsBody).foregroundStyle(Palette.textPrimary)
                        Spacer()
                    }
                }
                .buttonStyle(RowButtonStyle())
            }
        }
    }
}

/// VLC renders into a plain `UIView`.
private struct VLCVideoView: UIViewRepresentable {
    let model: VLCPlayerModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        model.start(in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
