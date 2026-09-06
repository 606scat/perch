# Perch

Native SwiftUI/AppKit utility for macOS 14+. This repository is the source and release home for `606scat/perch`.

## Installing or updating on another Mac

Read `docs/INSTALL.md`. Use the latest published disk image and native updater; the command-line installer remains an optional route. A source checkout and Xcode are not required to use Perch. Public downloads do not require GitHub authentication. Never copy signing keys, credentials, or local user data to another Mac.

The same installer command handles first install, updates, and already-current installations. Do not replace it with a script that deletes the data folder. Do not disable Gatekeeper, delete quarantine attributes, force-quit Perch, or reset macOS privacy permissions to work around installation trouble. Report the exact macOS or GitHub error.

## Data compatibility is a release contract

- Keep bundle identifier `local.af.perch` and `~/Library/Application Support/Perch/data.json` stable. App installation location is independent of this folder.
- Keep the kernel data lease and update lock. A second app copy must not write a stale snapshot over the first.
- Flush pending saves before quitting; a save failure or an open editor must cancel normal termination.
- App version/build numbers and the JSON data format are separate. New optional fields need decoding defaults. Breaking changes need an explicit migration, backup, and fixtures from every supported prior format. Never silently create an empty replacement after a decode failure.
- Preserve notes, drafts, snippets, projects, file bookmarks, focus state, chosen Reminders list, layout, shortcuts, themes, colors, and sound choices. Daily priorities intentionally reset on a new local day.
- The installer backs up local data and the previous app before replacement. Never automatically restore an older backup over newer live data or bypass downgrade checks.
- Do not package or commit local user data, credentials, review screenshots, or build output.

## Implementation and release checks

Read `PRODUCT.md` and `DESIGN.md` before UI changes. Run `swift test` for behavior changes. Release packages must pass `scripts/test-installer.py` after `scripts/package-release.sh`; this exercises real bundle replacement under temporary paths.

For release work read `docs/RELEASING.md`. A request to install/update a cofounder's Mac does not authorize publishing a new release. Only commit, push, tag, or publish when the owner requests that delivery. Never change repository visibility as part of an install.

Verify published release assets by downloading them and checking their checksums before calling a release available. Distinguish local checks, publication, and actual installation on the recipient's Mac.
