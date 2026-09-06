# Perch

A personal macOS widget dock built with SwiftUI and AppKit. Requires macOS 14 or later. Release packages support Apple Silicon and Intel.

## Install or update

Use the latest package from [GitHub Releases](https://github.com/606scat/perch/releases/latest), with access to this private repository. Follow [the install/update guide](docs/INSTALL.md), which includes a prompt to give Codex on another Mac. The same installer handles updates while preserving local data and making a backup first. A source build is not required.

The initial private build is development-signed and is not notarized. See the guide for macOS first-open approval and permission limits. To prepare a new version, follow [the release guide](docs/RELEASING.md).

## Build from source

Open `build/Perch.app`. To rebuild:

```sh
./scripts/build.sh
swift test
```

For an optimized local build, use `./scripts/build.sh release`. Shared releases use `scripts/package-release.sh` with a stable signing certificate and contain both Mac architectures.

## Use

- At rest, the dock tucks into its screen edge and leaves an 18-point strip. Hover the strip to reveal it. After you leave, it waits 3 seconds before easing back in. **Smooth dock motion** in Settings controls this slide independently of macOS Reduce Motion. Open widgets, file drags, and editing keep it available.
- Hover a widget to open its compact panel. Move away to dismiss a hover-opened panel. A shortcut-opened panel waits for you to enter it; moving the pointer back outside dismisses it. Typing and dialogs keep it open. Clicking the active widget again, clicking outside Perch, Escape, or pressing the same widget shortcut also closes it.
- Drag the dotted grip to the left, right, top, or bottom of a display. The dock remembers its edge, position, and display.
- Click **+** to add or remove widgets. Drag tiles to reorder them. Removing a widget preserves its data and running focus session; Undo is available briefly.
- The small keyboard control below each widget records a global shortcut. Include Command, Control, or Option. Escape cancels recording; Delete clears the shortcut. Press the same shortcut again to close its panel; another widget’s shortcut switches panels. Perch reports duplicates and system registration conflicts.
- **Control–Option–Space** opens Quick Capture.
- The bird in the macOS menu bar provides **Hide dock / Show dock**, direct widget access, Quick Capture, focus pause/resume, widget editing, Settings, and Quit. An active focus timer also shows its countdown there.
- **Settings → Appearance** offers System, Light, or Dark theme and six accent colors. Dark with blue remains the default. Turn off **Glass background** for solid panels. Appearance choices save automatically and apply to the dock, panels, and editors.

## Widgets

**Today:** Connect Apple Reminders and choose a writable list in Settings. Create or edit tasks with due dates, timed reminders, and recurrence. Pin up to three priorities for the current day. Complete a task or start focus from its menu.

**Notes:** Enter a title and optional description. Select a saved note to edit it. Changes and unfinished quick-note text are saved locally. Notes can become tasks after Reminders is connected.

**File tray:** Drag existing files or folders over the dock to reveal the tray, then release to add them. Choose Files is an alternate entry point. Drag items back out, use Quick Look or Share, or reveal them in Finder. Removing a tray item only removes its reference; originals stay in place.

**Snippets:** Save a named reply, link, command, or text. Click a saved snippet to copy it. Commands are copied as text.

**Projects:** Group website, app, file, or folder shortcuts by project. Open an individual shortcut or its group.

**Focus:** Start from a task or the Focus widget. Pause/resume or confirm stopping. The timer accounts for sleep and restart. Enable focus notifications in Settings for background alerts. Interaction and alert sounds have separate mute and volume controls.

## Local data

Data is saved atomically at `~/Library/Application Support/Perch/data.json`. The file tray stores references and bookmarks to originals. A malformed or newer data file is preserved, with writes disabled until resolved.

The `--demo` launch argument uses labeled synthetic content and disables persistent writes and live Reminders operations. No analytics or cloud service is used by Perch itself.

## Validation

See `docs/verification.md` for checks performed and integration gates. Apple Reminders access, notification delivery, and login startup depend on the user's macOS permissions and settings. This development build is not notarized for distribution.
