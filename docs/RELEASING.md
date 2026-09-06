# Prepare and publish a Perch update

Only publish when af requests it. Packaging alone does not commit, push, tag, or publish. The first package is `0.1.0`, build `1`; it is a private development release, not a notarized public distribution.

## Compatibility

Read the data contract in `AGENTS.md`. Keep the bundle ID and data path stable. Build numbers must strictly increase for published updates. Change `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist` for an authorized release; do not alter `PerchDataFormatVersion` or JSON `version` merely because the app version changes.

Future fields need defaults and an old-data regression fixture. A breaking data-format change requires a migration that backs up and preserves the prior file before writing. A downgrade must never wipe or silently reinterpret a newer format. The installer already refuses lower app build numbers.

## Local gates and package

```sh
swift test
security find-identity -v -p codesigning
PERCH_SIGNING_IDENTITY='THE_STABLE_CERTIFICATE_ID' ./scripts/package-release.sh
python3 scripts/test-installer.py
```

Use the same signing team and certificate type across updates. The private initial package uses the existing Apple Development certificate on the owner's Mac. Do not commit or copy its private key. For standard distribution use a Developer ID Application identity and set `PERCH_NOTARY_PROFILE` to an existing Keychain profile; the packaging script submits, waits, staples, and validates when that option is set. [Apple signing and notarization](https://developer.apple.com/developer-id/)

The package contains both `arm64` and `x86_64` slices. Output is `dist/vVERSION/` with `Perch-macOS-universal.zip`, `install-perch.command`, and `SHA256SUMS`. Review `codesign -dv --verbose=4 build/distribution/Perch.app` and verify the version/build in its Info.plist. Inspect runtime dependencies with `otool -L`; no dependency may point into the developer's checkout or a package-manager installation.

`test-installer.py` uses isolated temporary data and app directories. It checks first install, same-version no-op, update with byte-for-byte data preservation and backups, downgrade rejection, damaged downloads, concurrent installers, and unavailable downloads. Extend the cases when the installer or migration contract changes.

Launch the built app and verify Settings reports the version/build. Test a quit with an open editor and confirm it cancels without discarding the editor. Reuse the still-valid feature/theme evidence in `docs/verification.md`; record any changed behavior and unresolved device gates.

## Publication, after owner authorization

Reconcile the remote's current main branch without force-pushing or discarding remote changes. Review and commit only Perch source, resources, tests, scripts, and documentation. Generated packages, app data, credentials, and review captures stay out of Git.

Push the reviewed commit, create and push its matching `vVERSION` tag, then publish the three assets using GitHub CLI. Write release notes to `docs/releases/vVERSION.md` and use `--notes-file`.

```sh
gh release create vVERSION \
  dist/vVERSION/Perch-macOS-universal.zip \
  dist/vVERSION/install-perch.command \
  dist/vVERSION/SHA256SUMS \
  --repo 606scat/perch --verify-tag \
  --title 'Perch vVERSION' --notes-file docs/releases/vVERSION.md
```

Use normal releases in this private repo so the installer's latest-release lookup resolves them. If a future release is explicitly a GitHub prerelease, update the installation instructions to select its exact tag instead. Do not replace assets under an existing version; publish a higher build.

Download the published assets into a new temporary directory, verify their checksum, and compare the ZIP checksum to the local package. Confirm the release URL is accessible to the intended GitHub account. The cofounder can then use the same install/update prompt in `docs/INSTALL.md`.

## Recovery

Keep the failed release and affected data available for diagnosis. Do not advise running an old installer over a newer app. Prefer a fixed release with a higher build; manually restoring an old app or data backup needs explicit approval and a data-format compatibility check. Never automatically roll data back after the new app has started writing.
