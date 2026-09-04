#!/bin/sh

#  ci_pre_xcodebuild.sh
#  Xcode Cloud runs this after ci_post_clone.sh (project generated, packages
#  resolved) and right before xcodebuild.
#
#  project.yml pins CURRENT_PROJECT_VERSION to "1", so every archive would come
#  out as build "1.0 (1)". App Store Connect silently drops a build whose number
#  already exists — which is why a green Xcode Cloud build never shows up under
#  TestFlight / "Add Build". Stamp every build with Xcode Cloud's own
#  ever-increasing counter (CI_BUILD_NUMBER) so each one is unique.

set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "ci_pre_xcodebuild: CI_BUILD_NUMBER unset (local build?) — leaving the version as-is."
    exit 0
fi

cd "${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

# The app and the Top Shelf extension must ship the same CFBundleVersion.
for plist in Sources/App/Info.plist Sources/TopShelf/Info.plist; do
    if [ -f "$plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CI_BUILD_NUMBER" "$plist" 2>/dev/null \
            || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $CI_BUILD_NUMBER" "$plist"
        echo "ci_pre_xcodebuild: $plist  CFBundleVersion -> $CI_BUILD_NUMBER"
    else
        echo "ci_pre_xcodebuild: $plist not found (did ci_post_clone.sh run?)" >&2
        exit 1
    fi
done
