#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid release version/build.' >&2; exit 1; }
if [[ -n "${PERCH_PREBUILT_APP:-}" ]]; then
    # Preserve a cloud-signed, stapled Xcode export without rebuilding or re-signing.
    app="$PERCH_PREBUILT_APP"
    [[ -d "$app" ]] || { echo 'Prebuilt app does not exist.' >&2; exit 1; }
    codesign --verify --deep --strict "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute "$app"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" && "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$build" ]] || { echo 'Prebuilt version does not match the release source.' >&2; exit 1; }
else
    : "${PERCH_SIGNING_IDENTITY:?Set PERCH_SIGNING_IDENTITY, or supply a notarized PERCH_PREBUILT_APP.}"
    [[ "$PERCH_SIGNING_IDENTITY" != '-' ]] || { echo 'Shared releases require a stable certificate, not ad-hoc signing.' >&2; exit 1; }
    # Keep the running development bundle separate from the distributable.
    PERCH_BUNDLE_DIR="$PWD/build/distribution/Perch.app" ./scripts/build.sh release universal
    app="$PWD/build/distribution/Perch.app"
fi
/usr/bin/lipo "$app/Contents/MacOS/Perch" -verify_arch arm64 x86_64

# Optional Developer ID notarization. Credentials remain in the local Keychain.
if [[ -z "${PERCH_PREBUILT_APP:-}" && -n "${PERCH_NOTARY_PROFILE:-}" ]]; then
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

# A plain drag-to-Applications disk image works without a CLI or GitHub account.
dmg_stage=$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")
trap 'rm -rf "$dmg_stage"' EXIT
ditto "$app" "$dmg_stage/Perch.app"
ln -s /Applications "$dmg_stage/Applications"
cat > "$dmg_stage/Read me.txt" <<'GUIDE'
Perch

Drag Perch to Applications, then open it there. Eject this disk image afterward.
Requires macOS 14 or later. Apple Silicon and Intel are both supported.

Updates: click the Perch bird in the menu bar, then Check for updates.
Your data stays in ~/Library/Application Support/Perch/.

Installation help:
https://github.com/606scat/perch/blob/main/docs/INSTALL.md
GUIDE
hdiutil create -quiet -volname Perch -srcfolder "$dmg_stage" -format UDZO -ov "$out/Perch.dmg"
if [[ -z "${PERCH_PREBUILT_APP:-}" ]]; then
    codesign --force --timestamp --sign "$PERCH_SIGNING_IDENTITY" "$out/Perch.dmg"
fi
if [[ -z "${PERCH_PREBUILT_APP:-}" && -n "${PERCH_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$out/Perch.dmg" --keychain-profile "$PERCH_NOTARY_PROFILE" --wait
    xcrun stapler staple "$out/Perch.dmg"
    xcrun stapler validate "$out/Perch.dmg"
fi
(
    cd "$out"
    /usr/bin/shasum -a 256 Perch-macOS-universal.zip Perch.dmg install-perch.command > SHA256SUMS
)
printf 'Prepared version %s (build %s): %s\n' "$version" "$build" "$out"
printf 'No commit, tag, push, or GitHub release was made. See docs/RELEASING.md.\n'
