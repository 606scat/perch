# Install or update Perch

Perch supports Apple Silicon and Intel Macs running macOS 14 or later. Use the same process for a fresh installation or an update. No Xcode or Swift build is needed.

## Ask Codex on the other Mac

> Install or update Perch from the latest release of https://github.com/606scat/perch. Read its AGENTS.md and docs/INSTALL.md. Use the release installer, keep all existing Perch data, and verify the installed version and that it opens. If access or macOS approval is needed, tell me the exact step. Do not build from main, reset data or permissions, or disable Gatekeeper.

## One command sequence

The repository is private. Its owner must first give your cofounder's GitHub account read access. Install GitHub CLI if needed, then run `gh auth login` under that account. Codex can help with those steps. Do not share account credentials.

```sh
perch_download_dir="$(mktemp -d)"
gh release download --repo 606scat/perch --pattern install-perch.command --dir "$perch_download_dir"
/bin/bash "$perch_download_dir/install-perch.command"
```

The installer downloads the latest published release through your authenticated GitHub CLI. It verifies the ZIP checksum, bundle identifier, code signature, and CPU support. It installs to `~/Applications/Perch.app`, or updates an existing `/Applications/Perch.app` when writable. It refuses ambiguous duplicate installations and version downgrades.

If the exact build is already installed, it leaves it alone and opens it. When updating, it asks Perch to quit normally so pending saves finish. If an editor, file dialog, or save error keeps Perch open, finish or cancel that interaction and rerun the command. The installer never force-quits it.

## Data and backups

Your data stays at `~/Library/Application Support/Perch/data.json`, outside the app bundle. Notes, drafts, snippets, projects, file references, focus state, and preferences remain yours on that Mac. Updating does not sync or copy another person's data. Apple Reminders remains in the user's Apple account.

Before replacement, the installer backs up that local folder and the previous app under `~/Library/Application Support/Perch Backups/`. It verifies the saved JSON backup before installing. If recovery is needed, ask Codex to inspect the current file and available backups with Perch closed; restoring an older backup must be an explicit choice because it can discard newer edits.

A failed download or checksum leaves the installed app and saved data unchanged. A second installer stops at `.update-lock`; if an installer crashed, Codex should check that the recorded PID is no longer running before removing only that stale lock. A stale kernel `.data.lock` file is harmless; the kernel releases ownership when its process stops.

## macOS approval

The initial private build uses an Apple Development certificate and is not notarized. macOS may require an explicit first-open approval in System Settings → Privacy & Security → Open Anyway. Do not disable system protections to skip this. The owner needs a Developer ID Application certificate and notarization for normal distribution without that development-build limitation. [Apple distribution guidance](https://developer.apple.com/macos/distribution/)

App data is independent of macOS permission decisions. Initial installation, moving from an earlier ad-hoc build, certificate changes, or macOS policy may require Reminders/notification approval again. Continue using the same signing team/identity for later releases; do not promise that macOS can never ask again.

## Verify after installing

Open Settings in Perch and read the version/build near the bottom. Check an existing note, chosen appearance, and configured shortcut. New Macs start with their own empty data; existing Macs must retain theirs. Apple Reminders and notification permissions need the recipient's consent. Intel execution, first-open Gatekeeper behavior, and the cofounder's account permissions require verification on that Mac.
