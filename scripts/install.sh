#!/bin/bash
# The same command installs and updates. It never replaces the live data folder.
set -euo pipefail
umask 077
repo=606scat/perch
local_dir=''
launch=1
test_root=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --local-dir) local_dir="${2:?Missing directory}"; shift 2 ;;
        --no-open) launch=0; shift ;;
        --test-root) test_root="${2:?Missing test root}"; shift 2 ;;
        *) echo "Usage: $0 [--local-dir RELEASE_DIRECTORY] [--no-open]" >&2; exit 2 ;;
    esac
done
fail() { echo "Perch: $*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail 'This installer requires macOS.'
[[ "$(/usr/bin/sw_vers -productVersion | cut -d. -f1)" -ge 14 ]] || fail 'macOS 14 or later is required.'
base="$HOME"
if [[ -n "$test_root" ]]; then
    [[ -d "$test_root" && "$(basename "$test_root")" == perch-update-test.* && "$launch" == 0 ]] || fail 'Test mode needs an existing perch-update-test.* directory and --no-open.'
    base="$test_root"
fi
app_parent="$base/Applications"
data_dir="$base/Library/Application Support/Perch"
backup_parent="$base/Library/Application Support/Perch Backups"
if [[ -z "$test_root" && -e /Applications/Perch.app ]]; then
    [[ ! -e "$app_parent/Perch.app" ]] || fail 'Two installed copies exist. Keep one Perch.app before updating.'
    app_parent=/Applications
fi
destination="$app_parent/Perch.app"
[[ ! -L "$data_dir" && ! -L "$destination" ]] || fail 'App or data folder is a symbolic link. Resolve it before updating.'
mkdir -p "$app_parent" "$data_dir"
[[ -w "$app_parent" ]] || fail "No write access to $app_parent. Ask Codex to install into your user Applications folder."
scratch=$(mktemp -d "${TMPDIR:-/tmp}/perch-install.XXXXXX")
lock="$data_dir/.update-lock"
locked=0
stage=''
previous=''
cleanup() {
    local result=$?
    # Recover the previous bundle if replacement was interrupted after its move.
    if [[ -n "$previous" && -d "$previous" && ! -e "$destination" ]]; then mv "$previous" "$destination" || true; fi
    [[ -z "$stage" || ! -d "$stage" ]] || rm -rf "$stage"
    [[ "$locked" == 0 ]] || rm -rf "$lock"
    rm -rf "$scratch"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
if [[ -n "$local_dir" ]]; then
    cp "$local_dir/Perch-macOS-universal.zip" "$local_dir/SHA256SUMS" "$scratch/"
else
    command -v gh >/dev/null || fail 'GitHub CLI is required. Ask Codex to install gh, sign in, and retry.'
    gh release download --repo "$repo" --pattern Perch-macOS-universal.zip --pattern SHA256SUMS --dir "$scratch" || fail "Couldn’t download the latest release. Confirm internet access and GitHub access to $repo."
fi
expected=$(awk '$2 == "Perch-macOS-universal.zip" {print $1}' "$scratch/SHA256SUMS")
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || fail 'Missing or malformed archive checksum.'
actual=$(/usr/bin/shasum -a 256 "$scratch/Perch-macOS-universal.zip" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || fail 'Download checksum failed. The installed app and saved data are unchanged.'
# Only extract the known root, rejecting traversal before ditto sees the archive.
/usr/bin/unzip -Z1 "$scratch/Perch-macOS-universal.zip" > "$scratch/entries"
while IFS= read -r entry; do
    case "$entry" in Perch.app|Perch.app/*|__MACOSX/*) ;; *) fail 'Unexpected archive contents.' ;; esac
    case "/$entry/" in */../*|*/./*) fail 'Unsafe archive path.' ;; esac
done < "$scratch/entries"
/usr/bin/ditto -x -k "$scratch/Perch-macOS-universal.zip" "$scratch/unpacked"
incoming="$scratch/unpacked/Perch.app"
plist="$incoming/Contents/Info.plist"
[[ -f "$plist" && ! -L "$incoming" ]] || fail 'The release contains no valid Perch.app.'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" == local.af.perch ]] || fail 'Wrong application identifier.'
/usr/bin/codesign --verify --strict "$incoming" || fail 'App signature verification failed.'
/usr/bin/lipo "$incoming/Contents/MacOS/Perch" -verify_arch "$(uname -m)" || fail 'This release does not support this Mac.'
new_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
[[ "$new_build" =~ ^[1-9][0-9]*$ ]] || fail 'Invalid release build number.'
if [[ -e "$destination" ]]; then
    old_plist="$destination/Contents/Info.plist"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$old_plist")" == local.af.perch ]] || fail 'Refusing to replace an unrelated app.'
    old_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$old_plist")
    [[ "$old_build" =~ ^[1-9][0-9]*$ ]] || fail 'Installed app has an invalid build number.'
    [[ "$new_build" -ge "$old_build" ]] || fail "Refusing downgrade from build $old_build to $new_build."
    if [[ "$new_build" == "$old_build" ]]; then
        echo "Perch $version (build $new_build) is already installed. Your data is unchanged."
        [[ "$launch" == 0 ]] || /usr/bin/open "$destination"
        exit 0
    fi
fi
# A directory lock serializes installers; the app also checks it before opening.
if ! mkdir "$lock" 2>/dev/null; then
    fail "An update lock exists at $lock. Wait for the other installer; if it crashed, ask Codex to confirm its recorded PID is stopped before removing only that lock."
fi
locked=1
echo "$$" > "$lock/pid"
if [[ -z "$test_root" ]] && /usr/bin/pgrep -x Perch >/dev/null; then
    echo 'Quitting Perch so its latest changes can finish saving…'
    /usr/bin/osascript -e 'tell application id "local.af.perch" to quit' || fail 'Quit Perch from its menu bar, then retry. It has not been replaced.'
    for ((attempt=0; attempt<40; attempt++)); do
        /usr/bin/pgrep -x Perch >/dev/null || break
        sleep 0.25
    done
    /usr/bin/pgrep -x Perch >/dev/null && fail 'Perch is still open. Resolve its dialog or save error and retry; it will not be force-quit.'
fi
backup="$backup_parent/$(date -u +%Y%m%dT%H%M%SZ)-$new_build-$(/usr/bin/uuidgen)"
mkdir -p "$backup"
if [[ -f "$data_dir/data.json" ]]; then
    /usr/bin/ditto "$data_dir" "$backup/Data"
    rm -rf "$backup/Data/.update-lock"
    /usr/bin/cmp -s "$data_dir/data.json" "$backup/Data/data.json" || fail 'Data backup verification failed. Update stopped.'
fi
stage=$(mktemp -d "$app_parent/.perch-stage.XXXXXX")
/usr/bin/ditto "$incoming" "$stage/Perch.app"
/usr/bin/codesign --verify --strict "$stage/Perch.app" || fail 'Staged app failed verification.'
if [[ -d "$destination" ]]; then
    /usr/bin/ditto "$destination" "$backup/Perch.app"
    /usr/bin/codesign --verify --strict "$backup/Perch.app" || fail 'Previous-app backup failed verification.'
    # Same-filesystem rename retains the previous app until the new copy is ready.
    previous="$stage/Previous.app"
    mv "$destination" "$previous"
fi
mv "$stage/Perch.app" "$destination"
printf 'Installed Perch %s (build %s) at %s\n' "$version" "$new_build" "$destination"
printf 'Saved data stays at %s\nBackup: %s\n' "$data_dir" "$backup"
rm -rf "$lock"; locked=0
if [[ "$launch" == 1 ]]; then
    /usr/bin/open "$destination" || fail 'Installed successfully, but macOS did not open the app. Open Perch from Applications and review the macOS message.'
fi
echo 'If macOS blocks this private development build, review Privacy & Security → Open Anyway. This installer does not disable Gatekeeper or remove quarantine.'
