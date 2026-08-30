#!/bin/bash
# Writes your TMDB token into the (git-ignored) bundled-defaults file so
# metadata enrichment works without entering it on the Apple TV.
#
#   ./Scripts/set-tmdb-token.sh "eyJ...your token..."
#
set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $0 \"<TMDB v3 API key or v4 read access token>\"" >&2
  exit 1
fi

FILE="$(cd "$(dirname "$0")/.." && pwd)/Sources/App/TMDBDefaults.swift"
TOKEN="$1"

cat > "$FILE" <<EOF
import Foundation

/// Bundled TMDB credentials (git-ignored). A key set in Settings overrides this.
/// Regenerate with ./Scripts/set-tmdb-token.sh
enum TMDBDefaults {
    static let readAccessToken = "$TOKEN"
}
EOF

# Never track local edits to this file.
git -C "$(dirname "$FILE")/../.." update-index --skip-worktree Sources/App/TMDBDefaults.swift 2>/dev/null || true

echo "Wrote token to $FILE"
echo "Now: xcodegen generate && build."
