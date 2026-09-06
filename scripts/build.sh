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
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Resources/Sounds"
cp "$binary_dir/Perch" "$bundle_dir/Contents/MacOS/Perch"
cp Resources/Info.plist "$bundle_dir/Contents/Info.plist"
cp Resources/Sounds/*.wav "$bundle_dir/Contents/Resources/Sounds/"
# UserNotifications looks for custom alert sounds at the bundle resource root.
cp Resources/Sounds/finish.wav "$bundle_dir/Contents/Resources/finish.wav"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$bundle_dir/Contents/Resources/AppIcon.icns"
fi
signing_identity="${PERCH_SIGNING_IDENTITY:--}"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --sign - "$bundle_dir"
else
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$bundle_dir"
fi
codesign --verify --strict "$bundle_dir"
print "Built $bundle_dir ($configuration, $architecture)"
