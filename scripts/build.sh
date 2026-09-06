#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-debug}"
architecture="${2:-native}"
if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
    print -u2 "Usage: scripts/build.sh [debug|release] [native|universal]"
    exit 2
fi
build_args=(-c "$configuration")
case "$architecture" in
    native) ;;
    universal) build_args+=(--arch arm64 --arch x86_64) ;;
    *) print -u2 "Architecture must be native or universal"; exit 2 ;;
esac
swift build "${build_args[@]}"
binary_dir="$(swift build "${build_args[@]}" --show-bin-path)"
bundle_dir="${PERCH_BUNDLE_DIR:-$PWD/build/Perch.app}"
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Resources/Sounds" "$bundle_dir/Contents/Resources/Ambient" "$bundle_dir/Contents/Frameworks"
cp "$binary_dir/Perch" "$bundle_dir/Contents/MacOS/Perch"
# SwiftPM may add a toolchain-only fallback. Recipient Macs do not need Xcode.
while IFS= read -r runtime_path; do
    if [[ "$runtime_path" == /Applications/* || "$runtime_path" == "$PWD"/* ]]; then
        install_name_tool -delete_rpath "$runtime_path" "$bundle_dir/Contents/MacOS/Perch"
    fi
done < <(otool -l "$bundle_dir/Contents/MacOS/Perch" | awk '/cmd LC_RPATH/ { getline; getline; sub(/^[[:space:]]*path /, ""); sub(/ \(offset.*/, ""); if (!seen[$0]++) print }')
cp Resources/Info.plist "$bundle_dir/Contents/Info.plist"
cp Resources/Sounds/*.wav "$bundle_dir/Contents/Resources/Sounds/"
cp Resources/Ambient/*.wav "$bundle_dir/Contents/Resources/Ambient/"
sparkle_source="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
sparkle="$bundle_dir/Contents/Frameworks/Sparkle.framework"
# Perch is not sandboxed, so Sparkle's optional XPC services are unnecessary.
if [[ -d "$sparkle" ]]; then rm -rf "$sparkle"; fi
ditto "$sparkle_source" "$sparkle"
rm -rf "$sparkle/Versions/B/XPCServices" "$sparkle/XPCServices"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$bundle_dir/Contents/Resources/Sparkle-LICENSE.txt"
# UserNotifications looks for custom alert sounds at the bundle resource root.
cp Resources/Sounds/finish.wav "$bundle_dir/Contents/Resources/finish.wav"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$bundle_dir/Contents/Resources/AppIcon.icns"
fi
signing_identity="${PERCH_SIGNING_IDENTITY:--}"
sign_args=(--force --sign "$signing_identity" --options runtime)
if [[ "$signing_identity" != "-" ]]; then sign_args+=(--timestamp); fi
codesign "${sign_args[@]}" "$sparkle/Versions/B/Autoupdate"
codesign "${sign_args[@]}" "$sparkle/Versions/B/Updater.app"
codesign "${sign_args[@]}" "$sparkle"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --sign - "$bundle_dir"
else
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$bundle_dir"
fi
codesign --verify --deep --strict "$bundle_dir"
print "Built $bundle_dir ($configuration, $architecture)"
