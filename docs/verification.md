# Verification — September 6, 2026

Perch 0.2.0, build 2. This report separates local validation, private release publication, and another Mac's installation. The package is development-signed, not notarized.

## Current automated checks

The final source suite passes **49 tests**. Coverage includes:

- Focus countdown through sleep/restart, pause/resume, duplicate start protection, idle/running clock cadence, completion after wake, and timer cleanup.
- Daily priorities, notes/drafts, snippets, file references/bookmarks, project URL safety, widget order/Undo, shortcut conflicts and toggling, menu-bar access, and appearance persistence/contrast.
- Four dock edges, external-display coordinates, pointer clamping, small flyouts, feedback height, the reachable peek strip, and all 14 widget selections under a constrained rail length.
- Native Finder file URL decoding and drag destination integration, original-file preservation, and locked-storage rejection.
- Calculator precedence, unary operators, percentages, scientific notation, invalid input, division by zero, non-finite results, and bounded expressions/history.
- Unit conversions including temperature offsets, fractional units, decimal/binary data sizes, and reverse conversions across every compatible unit pair.
- Habit local-day and daylight-saving boundaries, streak continuation from yesterday, rename/history preservation, deletion/Undo, and past/today/future countdowns.
- Manual clipboard capture, exact text preservation, deduplication, size/history limits, source privacy markers, and deletion/Undo.
- World-clock seasonal offsets and fractional time zones, modern/legacy city search aliases, breathing elapsed-time phases/completion, and temporary session restart behavior.
- Keep Awake assertion creation, duplicate starts, timed expiry, partial-creation failure cleanup, and deinitialization cleanup with an injected backend.
- Format 1 migration with an exact backup and preserved collections/preferences; format 2 utility round-trip; future-format rejection; migration-backup failure locking writes without changing the original file.
- Exclusive data ownership, installer/app exclusion, immediate quit-time saving, failed-save retention, and reopening saved content.

The final universal package passes **8 isolated installer scenarios**: existing-data first install, fresh install, same-build no-op, upgrade with exact data/prior-app backups, downgrade rejection, damaged archive rejection, concurrent installer rejection, and unavailable-download failure. Temporary paths include spaces and Unicode. These tests do not install over the owner's app or use the owner's data.

Logs: `.impeccable/review/widgets-tests-final.log`, `widgets-installer-final.log`, and `widgets-package.log`.

## Live checks for the new widgets

| Behavior | Observed result |
| --- | --- |
| Widget library | All 14 entries, search, adding/removing all eight additions, and lower rows reached by scrolling. |
| Long dock | 640pt vertical cap; scrolling reaches the lower widgets while grip and add stay visible. Other-edge dimensions also have automated coverage. |
| Calculator | Entered `2+3*4`, received `14`, and copied the result. History appeared and survived restart. |
| Clipboard | Explicitly captured that known test result and displayed its exact text/count. No background capture was enabled. |
| Converter | Rendered a meters-to-feet conversion and swapped the units. Final swap uses the full numeric value to avoid a display-rounding round trip. |
| World clock | Live local times/dates/UTC offsets rendered. The corrected Kolkata search returned `Asia/Kolkata`. |
| Countdowns | Created a named date seven days ahead, displayed seven days left, then deleted through confirmation. |
| Habits | Created a habit, completed today, observed the seven-day marker and one-day streak, then deleted through confirmation. |
| Breathing | Began a one-minute session, observed the phase/countdown, and ended it. |
| Keep Awake | Started a timed session; `pmset` showed Perch's `PreventUserIdleSystemSleep` assertion with timeout release. Stop removed the assertion. |
| Appearance | New widget captures in Dark; new calculator capture in Light. The selected appearance follows the existing shared semantic palette. |
| Data migration | The owner's prior JSON has an exact migration backup. Existing saved collections and non-test preferences were preserved. The original six-widget layout and Dark/Blue/glass preferences were restored after testing. |

The temporary habit/countdown were deleted through their dialogs. Known calculator/clipboard test entries were removed afterward while the app was quit and the data lease was held. Temporary shortcut configuration was cleared. Existing user data was not replaced with a test fixture.

The independent fresh finishing reviewer returned **ship** with no material findings in the eight widgets, gallery, capped dock, migration, and associated source/tests. It inspected all eight widget captures, both gallery positions, both dock scroll positions, corrected city search, and Light calculator. This is a scoped local verdict, not a guarantee against every possible defect.

## Earlier evidence still applicable

The user physically verified file dropping and a global widget shortcut opening from another foreground app. Earlier actual-app checks covered notes create/edit/delete, file remove/Undo, focus pause, shortcut recording/toggling, Quick Capture, compact flyouts, and contained feedback. Appearance checks covered Dark/blue/glass, Light/blue/glass, Light/purple/solid, persistence after restart, sheet accent inheritance, and switching Light back to System on this currently Dark Mac.

Quit-time protection was exercised in the packaged app: an open Quick Capture editor canceled normal termination; canceling that empty editor then allowed a normal quit. The new editors use the same native attached-sheet protection. macOS Reduce Motion remains enabled on this Mac; Perch's separate Smooth dock motion option provides the user-requested dock animation.

## Resource behavior

No new network polling or clipboard observer was added. The shared clock runs once per minute while idle/paused and once per second for active focus or breathing; wake/clock-change events catch up from wall time. Breathing animation is capped at 30 frames per second only in its visible panel and is disabled for Reduce Motion. Keep Awake uses native timed assertions and a one-shot cleanup timer. Colors are cached native providers; solid appearance removes the visual-effect view.

Earlier v0.1.0 short idle observations measured CPU rounded to 0.0% at `ps` resolution and a 27 MB physical footprint over 20 seconds. Those measurements predate the new widgets and are not a benchmark for v0.2.0 or a long-session leak guarantee.

## Package and remaining gates

The optimized universal package contains arm64 and x86_64 slices targeting macOS 14, with system frameworks only. Strict signature verification passed using the same Apple Development identity and hardened runtime. The ZIP is approximately 4 MB. It is not Developer ID signed or notarized.

Physical world-clock slider adjustment was not verified: the automation adapter could read it but did not successfully adjust it. Its native SwiftUI binding and date-specific conversion math were reviewed, with the math tested. Physical horizontal/multi-display dock movement, VoiceOver traversal, every new panel in every accent/theme, externally changing System appearance while running, background notifications, login startup, and Apple Reminders account operations remain device/integration checks. No Reminders permissions were granted or account tasks changed by the agent. The current app shows Connect for Reminders.

File tray supports existing local file/folder URLs. Promised-file drags without a local URL are not implemented. A cofounder's Mac still needs macOS 14+, repository access, first-open approval for this development build, and its own Reminders/notification consent. Intel execution and installation on the actual recipient Mac were not exercised. macOS governs permission retention across signed updates.

## Private release delivery

Source commit `4f0963d` and tag `v0.2.0` were pushed to the existing private repository. [Perch v0.2.0](https://github.com/606scat/perch/releases/tag/v0.2.0) is a published normal release with the universal app ZIP, installer, and checksums. All three downloaded assets matched their local counterparts byte-for-byte; checksum verification passed. The downloaded installer then fetched the latest published release and successfully installed build 2 in an isolated temporary destination. The ZIP is 4,196,061 bytes.

The primary local app at `build/Perch.app` was refreshed from that verified universal bundle and is running. A final read after restart confirmed the original preferences and saved collections, with no verification items remaining. No build, test, installer, or publishing job is still running. The actual recipient Mac remains an installation/permission gate; future updates use `docs/INSTALL.md` and `docs/RELEASING.md`.
