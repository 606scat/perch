#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${PERCH_SIGNING_IDENTITY:?Set PERCH_SIGNING_IDENTITY to your stable signing certificate before packaging a shared release.}"
[[ "$PERCH_SIGNING_IDENTITY" != '-' ]] || { echo 'Shared releases require a stable certificate, not ad-hoc signing.' >&2; exit 1; }
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid release version/build.' >&2; exit 1; }
# Keep the running development bundle separate from the distributable.
PERCH_BUNDLE_DIR="$PWD/build/distribution/Perch.app" ./scripts/build.sh release universal
app="$PWD/build/distribution/Perch.app"
/usr/bin/lipo "$app/Contents/MacOS/Perch" -verify_arch arm64 x86_64

# Optional Developer ID notarization. Credentials remain in the local Keychain.
if [[ -n "${PERCH_NOTARY_PROFILE:-}" ]]; then
    /usr/bin/codesign -dv "$app" 2>&1 | /usr/bin/grep -q 'Authority=Developer ID Application:' || { echo 'Notarization requires a Developer ID Application signature.' >&2; exit 1; }
    /usr/bin/ditto -c -k --keepParent "$app" build/notary-submission.zip
    xcrun notarytool submit build/notary-submission.zip --keychain-profile "$PERCH_NOTARY_PROFILE" --wait
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
fi
out="$PWD/dist/v$version"
mkdir -p "$out"
/usr/bin/ditto -c -k --keepParent "$app" "$out/Perch-macOS-universal.zip"
cp scripts/install.sh "$out/install-perch.command"
chmod +x "$out/install-perch.command"
(
    cd "$out"
    /usr/bin/shasum -a 256 Perch-macOS-universal.zip install-perch.command > SHA256SUMS
)
printf 'Prepared version %s (build %s): %s\n' "$version" "$build" "$out"
printf 'No commit, tag, push, or GitHub release was made. See docs/RELEASING.md.\n'
