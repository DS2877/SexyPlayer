import Foundation

/// Which playback stack handles a given URL.
///
/// `AVPlayer` is preferred where it works (HLS, MP4/MOV) — it's lighter, has the
/// polished native transport UI, and better power behaviour. Everything else —
/// MKV, AVI, raw MPEG-TS, rtmp/rtsp — goes to VLC, which decodes almost anything.
public enum PlaybackEngine: String, Sendable, Equatable {
    case system
    case vlc

    public static func choose(for url: URL) -> PlaybackEngine {
        // Non-HTTP streaming protocols (rtmp, rtsp, mms, udp…) — only VLC.
        switch (url.scheme ?? "").lowercased() {
        case "http", "https", "":
            break
        default:
            return .vlc
        }

        let full = url.absoluteString.lowercased()
        if full.contains("m3u8") { return .system }   // HLS, extension or not

        switch url.pathExtension.lowercased() {
        case "m3u8", "m3u", "mp4", "mov", "m4v", "m4a", "mp3", "aac":
            return .system
        case "":
            // Extension-less HTTP: Xtream live is HLS by our URL builder; VOD isn't.
            return url.pathComponents.contains("live") ? .system : .vlc
        default:
            return .vlc   // mkv, avi, ts, flv, wmv, vob…
        }
    }
}
