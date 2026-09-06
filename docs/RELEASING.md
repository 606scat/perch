# Releasing Perch

Publish only when the owner requests delivery. Packaging alone does not commit, push, tag, publish, or change visibility. Public source and downloads were authorized for version 0.3.0.

## Compatibility checks

Keep `local.af.perch` and the local data path stable. Increment the app version and build in `Resources/Info.plist`. Change `PerchDataFormatVersion` only when the data contract requires it, with exact migration backups and tests for supported older formats. Never lower the build number or overwrite existing release assets.

Run:

```sh
swift test
git diff --check
```

Inspect the affected widgets in the native app. Exercise save/quit behavior, themes, long content, and any migration. Keep personal data and review captures out of Git.

## Signing and packaging

The build embeds Sparkle 2.9.6 and signs its nested helpers before the framework and app. The unused sandbox XPC services are omitted, as described by [Sparkle](https://sparkle-project.org/documentation/sandboxing/).

For Xcode cloud signing, sign in to an Apple Developer account in **Xcode → Settings → Accounts**. Set `PERCH_SIGNING_IDENTITY` to the local Apple Development identity and `PERCH_DEVELOPMENT_TEAM` to its team identifier. The script creates a universal app and archive; Xcode then uses the account’s Developer ID signing service and uploads it for notarization. It does not export private keys. [Apple’s distribution guidance](https://developer.apple.com/developer-id/).

```sh
./scripts/notarize-xcode.sh upload
# Once Apple has finished processing:
./scripts/notarize-xcode.sh export
```

If export reports that processing is still in progress, retry **export** later. Do not upload the same build again. The export command prints the exact packaging command:

```sh
PERCH_PREBUILT_APP="/absolute/path/to/export/Perch.app" ./scripts/package-release.sh
python3 scripts/test-installer.py
```

The prebuilt path is checked for the matching version/build, strict signature, stapled ticket, Gatekeeper acceptance, and both architectures. Packaging preserves that signature and ticket. The resulting DMG contains the notarized app; the outer disk image is not separately signed or notarized in this cloud-signing route.

Maintainers with a local Developer ID Application identity can instead set `PERCH_SIGNING_IDENTITY` to that identity, set `PERCH_NOTARY_PROFILE` to an existing `notarytool` Keychain profile, and run `scripts/package-release.sh`. This route submits and staples both the app and disk image. Credentials remain in Keychain.

Packaging produces `Perch.dmg`, `Perch-macOS-universal.zip`, `install-perch.command`, and `SHA256SUMS` in `dist/vVERSION`. The installer tests use that actual ZIP, including for isolated upgrade fixtures. Development builds are suitable for local work; shared releases should use a verified notarized app.

## Signed update feed

The app’s `SUPublicEDKey` identifies a release-signing key stored under the `local.af.perch` account by Sparkle’s `generate_keys` tool. Keep that private key in Keychain. Never regenerate or rotate it casually: installed apps trust the existing public key.

The app requires a signed feed and verifies update archives before extraction. Silent automatic installation is disabled. The delegate blocks installation for open editors or protected storage, flushes pending saves, and creates an exact backup. The normal quit gate checks again before exit.

Write `docs/releases/vVERSION.md` and a short HTML counterpart for the update dialog, then run:

```sh
./scripts/generate-appcast.sh
```

This generates and signs `appcast.xml` using the matching ZIP. Do not edit the signed XML by hand. Regenerate it after any change. Publish the exact archive that was signed. See [Sparkle’s publishing guide](https://sparkle-project.org/documentation/publishing/).

## Publish and verify

Commit scoped source, docs, and the lockfile. Tag the release version. Publish all four packaged assets and the release notes to `606scat/perch`. Make the assets available before pushing the new `appcast.xml` so installed apps cannot see an update whose download does not exist.

Download the published assets into a new temporary folder with no GitHub credentials, verify the checksums, and compare the ZIP and DMG to the local packages. Mount the downloaded DMG read-only and verify its app signature and architectures. Check the anonymous update-feed response and use **Check for updates…** in the release app. Inspect the GitHub check run before reporting completion.

Do not claim notarization, an actual upgrade on another Mac, or Intel execution from a successful local build. Record the evidence and remaining device gates in `docs/verification.md`.
