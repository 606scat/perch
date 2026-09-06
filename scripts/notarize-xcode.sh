#!/bin/bash
# Xcode cloud signing keeps the Developer ID private key off the checkout.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
root="$PWD/build/notarization/v$version-build$build"
archive="$root/Perch.xcarchive"
case "${1:-}" in
upload)
    : "${PERCH_SIGNING_IDENTITY:?Set the local Apple Development signing identity.}"
    : "${PERCH_DEVELOPMENT_TEAM:?Set the Apple Developer team identifier.}"
    [[ ! -e "$archive" ]] || { echo "Archive already exists: $archive. Export it or use a new release build." >&2; exit 1; }
    PERCH_BUNDLE_DIR="$PWD/build/distribution/Perch.app" ./scripts/build.sh release universal
    mkdir -p "$archive/Products/Applications"
    ditto build/distribution/Perch.app "$archive/Products/Applications/Perch.app"
    python3 - "$archive" "$PERCH_DEVELOPMENT_TEAM" <<'PY'
import datetime, pathlib, plistlib, sys
archive = pathlib.Path(sys.argv[1])
info = plistlib.loads((archive / 'Products/Applications/Perch.app/Contents/Info.plist').read_bytes())
properties = {k: info[k] for k in ['CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion']}
properties.update(ApplicationPath='Applications/Perch.app', SigningIdentity='Apple Development', Team=sys.argv[2])
data = dict(ArchiveVersion=2, CreationDate=datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), Name='Perch', SchemeName='Perch', ApplicationProperties=properties)
(archive / 'Info.plist').write_bytes(plistlib.dumps(data))
options = dict(method='developer-id', signingStyle='automatic', teamID=sys.argv[2], destination='upload', manageAppVersionAndBuildNumber=False)
(archive.parent / 'ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY
    xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$root/ExportOptions.plist" -allowProvisioningUpdates
    echo 'Uploaded. After Apple finishes processing, run scripts/notarize-xcode.sh export.'
    ;;
export)
    xcodebuild -exportNotarizedApp -archivePath "$archive" -exportPath "$root/export"
    codesign --verify --deep --strict "$root/export/Perch.app"
    xcrun stapler validate "$root/export/Perch.app"
    spctl --assess --type execute "$root/export/Perch.app"
    printf 'Package with PERCH_PREBUILT_APP="%s/export/Perch.app" ./scripts/package-release.sh\n' "$root"
    ;;
*) echo 'Usage: scripts/notarize-xcode.sh upload|export' >&2; exit 2 ;;
esac
