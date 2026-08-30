import Foundation

/// Bundled TMDB credentials so metadata enrichment works with no on-TV setup.
///
/// The token below is filled in **locally** on the build machine and kept out
/// of git (a token doesn't belong in source history, even a free read-only one).
/// A key set in Settings → Artwork & metadata always overrides this.
///
/// To set it on a fresh checkout, run from the repo root:
///
///     ./Scripts/set-tmdb-token.sh "<your token>"
///
enum TMDBDefaults {
    /// v3 API key **or** v4 "API Read Access Token" — `TMDBClient` detects which.
    static let readAccessToken = ""
}
