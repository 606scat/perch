# Install & update Perch

Requires macOS 14 or later. The same download supports Apple Silicon and Intel Macs.

## Install

1. [Download Perch.dmg](https://github.com/606scat/perch/releases/latest/download/Perch.dmg).
2. Open the disk image and drag **Perch** to **Applications**.
3. Open Perch from Applications. Look for its bird in the menu bar and the slim dock at the screen edge.
4. Eject the disk image.

You do not need GitHub, Terminal, Xcode, or Codex to use Perch.

The app is signed with Developer ID and notarized by Apple. macOS may ask you to confirm that you want to open an app downloaded from the internet. If it instead reports a damaged or blocked app, [report the exact message](https://github.com/606scat/perch/issues). Leave system security protections enabled.

## Update

From Perch’s menu-bar bird or Settings, choose **Check for updates…**. Review the new version, then choose to install and relaunch. Finish any open editor or file dialog first. Perch saves your latest changes and verifies a local backup before it permits the update.

You can enable automatic **checks** in Settings. You still choose when to install. Checks require an internet connection; your widgets work offline.

**Coming from 0.1 or 0.2?** Those builds do not have the updater. Quit Perch, download the latest disk image, and replace the existing app in Applications once. Future updates can happen inside Perch. Replacing the app does not replace its separate data folder.

## Data and recovery

Your data lives at `~/Library/Application Support/Perch/data.json`, independent of the app’s location. Each Mac has its own data. In-app updates keep exact JSON snapshots under `~/Library/Application Support/Perch Backups/`. Format upgrades also create `Migration Backups` beside the live data file.

If you need to recover, quit Perch and copy the current data somewhere safe before choosing a backup. Restoring a backup discards changes made after that snapshot, so Perch does not restore one on its own. A malformed or newer-format file opens in a protected state instead of being replaced with empty data.

Apple Reminders, notifications, and login startup require your own macOS permissions. Choose a Reminders list in Perch Settings after granting access. Permission retention across updates remains under macOS control.

## Optional command-line installer

The release also includes `install-perch.command` for scripted installation. It uses macOS’s built-in `curl`, checks the archive checksum and bundle signature, backs up existing app/data, and refuses downgrades. No GitHub sign-in is required. Download it from the [latest release](https://github.com/606scat/perch/releases/latest), inspect it, and run it if you prefer this route.

The installer never force-quits Perch. Resolve an open editor or save error, then retry. It serializes updates with a lock in the data folder. If a crashed installer leaves a lock, confirm that its recorded process has stopped before removing that lock; do not delete the data folder.
