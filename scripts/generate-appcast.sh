#!/bin/bash
# Signs the feed and archive with the release key held in the local Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
archive="$PWD/dist/v$version/Perch-macOS-universal.zip"
[[ -f "$archive" ]] || { echo 'Package the release first.' >&2; exit 1; }
stage=$(mktemp -d "$PWD/build/appcast-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
cp "$archive" "$stage/"
if [[ -f appcast.xml ]]; then cp appcast.xml "$stage/appcast.xml"; fi
if [[ -f "docs/releases/v$version.html" ]]; then cp "docs/releases/v$version.html" "$stage/Perch-macOS-universal.html"; fi
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --account local.af.perch --maximum-deltas 0 --embed-release-notes \
    --download-url-prefix "https://github.com/606scat/perch/releases/download/v$version/" \
    --link 'https://github.com/606scat/perch' \
    --full-release-notes-url "https://github.com/606scat/perch/releases/tag/v$version" \
    "$stage"
cp "$stage/appcast.xml" appcast.xml
echo 'Signed appcast.xml. Publish the matching assets before pushing this feed.'
