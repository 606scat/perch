# Verification — September 7, 2026

## Version 0.3.2 corner fix

Build 5 retains data format 3. The native glass material now has its own mask, matching the rail's continuous 16pt rounded shape before the dock is clipped into its narrow peek strip. The mask follows vertical and horizontal resizing and is reused for unchanged sizes.

- All **63 tests** passed, including corner alpha, interior opacity, vertical/horizontal resize, mask reuse, and mask removal checks.
- All **8 installer scenarios** passed against the final notarized release ZIP.
- Native Dark and Light, expanded and tucked, plus horizontal Top captures were inspected. The owner confirmed the reported black corners are gone against the original desktop backdrop. A fresh independent reviewer returned **ship** for this corner fix.
- The original Left/Dark layout was restored. The owner's JSON remained byte-for-byte identical before and after replacement with the final notarized app.
- Developer ID signature, nested-code verification, stapled ticket, Gatekeeper acceptance, and both binary architectures passed. The ZIP and feed signatures match the public key embedded in Perch.

[Perch 0.3.2](https://github.com/606scat/perch/releases/tag/v0.3.2) is public. Source/tag commit `513da4f` contains the fix; `73f952d` publishes its signed feed after the assets became available. All four anonymously downloaded assets matched the local packages byte for byte and passed SHA-256 checks. The downloaded DMG app passed strict signature, stapled-ticket, Gatekeeper, version/build, and architecture checks. Its downloaded installer fetched and installed public build 5 in an isolated destination. The live notarized app reported “Perch 0.3.2 is currently the newest version available.” Owner data stayed byte-identical after restart and that update check.

[GitHub Mac checks](https://github.com/606scat/perch/actions/runs/34092491206) passed for the release source: behavior tests, app build, embedded-code verification, and whitespace.

The DMG is 11,380,250 bytes; the ZIP is 10,789,294 bytes; the optional installer is 7,313 bytes; SHA256SUMS is 256 bytes. This patch does not claim another complete Sparkle upgrade cycle; the actual 0.3.0 → 0.3.1 upgrade evidence below remains applicable to the unchanged updater. Earlier release evidence below remains historical, and the remaining device checks still apply.

## Version 0.3.1 verification

Perch 0.3.1, build 4, data format 3. Version 0.3.0 introduced the new widgets and public distribution; 0.3.1 corrects two legacy messages in the optional installer. This report separates automated checks, observations in the native app, public delivery, and checks that still require another device.

## Automated behavior and installation

The final source suite passes **62 tests**. The actual packaged release passes **8 isolated installer scenarios**.

| Area | Evidence |
| --- | --- |
| Saved data | Format 1 and 2 migrate with exact backups; format 3 round-trips new fields; newer formats and failed migration backups lock writes without replacing the original file. |
| Updates | Pending changes save before an exact, verified backup. Open editors, file dialogs, protected data, failed saves, and backup failures block installation. |
| Concurrent access | The kernel data lease and installer lock prevent competing writers and app/installer replacement races. |
| Focus and clocks | Pause/resume, sleep/restart, wall-clock completion, idle timer cadence, day boundaries, duplicate completion, and cleanup. A regression test delivers the calendar-day callback from a background task and verifies main-thread publication. |
| Existing tools | Notes/drafts, shortcuts, widget selection, file URLs/bookmarks, project URL safety, calculator errors and bounds, compatible unit round trips, clipboard privacy markers, habits, dates, time zones, and Keep Awake assertions. |
| New tools | Hex parsing and bounds, Unicode QR payload decoded with Apple Vision, text transformations and line endings, bounded choices, normalized drawing points and PNG output, garden daily/focus rewards, and persistent preferences. |
| Audio | All four bundled loops decode with AVAudioFile; generated samples have bounded peaks and matched loop boundaries. |
| Layout | Dock edges, constrained rail length, flyout fitting, feedback heights, and appearance contrast retain automated coverage. |
| Installer | Existing-data first install, fresh install, same-build no-op, upgrade with exact data/prior-app backups, downgrade rejection, damaged archive rejection, concurrent installation rejection, and unavailable-download failure. Paths include spaces and Unicode. |

The installer fixtures are extracted from the final release ZIP. Tests use temporary app/data destinations and remove them after completion. Logs remain local under `.impeccable/review/`; no owner data or test captures are published there.

## Observed in the native app

| Behavior | Result |
| --- | --- |
| Widget library | All 20 entries are reachable. Practical tools precede Relax and the playful widgets. Adding widgets, searching, scrolling, and restoring the original six were exercised. |
| Dock text | Final Notes, Focus, Snippets, and Projects tiles use complete short labels/status/counts. Long focus text remains available in its flyout and tooltip. |
| Relax | Started five-minute breathwork with ambient sound and spoken guidance enabled, observed its active phase/countdown, ended it, and returned both options to off. |
| Colors | Added and copied a known hex swatch; the native screen sampler returned a color. The known manual test swatch was removed. |
| QR | Generated a code for a synthetic URL, copied/saved its PNG through the native save dialog, and inspected Light and Dark appearances. |
| Text tools | Verified word/character/line counts and duplicate-line removal while preserving the input. |
| Quick decisions | Flipped a coin, rolled a die, selected from two choices, and verified empty choices disable picking. |
| Doodle | Drew strokes, undid one, cleared through confirmation, restored through Undo, and inspected Light and Dark canvases. |
| Tiny garden | Inspected the initial seed and confirmed its complete instruction text after the final layout correction. Daily growth was checked by tests rather than watering the owner’s plant. |
| Updates | The public signed feed reported 0.3.0 current, then offered 0.3.1. The native updater downloaded, installed, and relaunched into build 4. Saved data remained byte-for-byte unchanged; both new update snapshots matched it exactly. |
| Restart and data | The owner’s prior JSON has an exact migration backup. Saved collections and unrelated preferences were preserved. Known QA text/drawing inputs were removed under the data lease while the app was quit; the original six widgets and Dark appearance were restored. |

The prior running 0.2.0 app froze at the local day change: an Objective-C calendar notification entered SwiftUI publication from a background queue. The captured thread sample identified the deadlock. Version 0.3.0 explicitly hops that notification to the main actor and includes the regression test above.

Earlier still-applicable checks include the owner’s physical file drop and cross-app global shortcut, note editing, focus pause, Quick Capture, removal/Undo, quit cancellation with an open editor, multiple dock appearances, actual Keep Awake assertion start/stop, and live creation/deletion of a temporary habit and countdown.

The fresh independent reviewer inspected fourteen valid final captures and found no material visual corrections. Its sole documentation finding was corrected in DESIGN.md and the design sidecar; the reviewer scored that fix resolved with disposition **ship**. The review did not exercise audio playback or perform an update installation.

## Resource behavior

Widgets use the existing shared clock: once per minute while idle or paused, once per second during a timed focus/Relax session, with wall-clock catch-up after wake. Breathing animation runs only in its visible panel, at 30 frames per second, and respects Reduce Motion. Ambient playback uses one looped native player; speech initializes only when requested. Clipboard capture remains manual. QR rendering is debounced. Sparkle owns update scheduling without an additional poller.

## Release checks

The universal app contains arm64 and x86_64 slices targeting macOS 14. Its embedded Sparkle framework is included, with toolchain-only runtime search paths removed. Developer ID signing, strict nested-code verification, stapled-ticket validation, and Gatekeeper assessment passed for the final export: **accepted — Notarized Developer ID**. The DMG contains that exact notarized app; this release’s outer disk image is not separately notarized.

The public-history audit inspected all five earlier commits and their reachable content. Credential-pattern and sensitive-path scans found no matching secrets or local data. The current source scan likewise found none. Build output, review captures, signing credentials, and local data are excluded. The two README screenshots contain only the native Relax UI and a synthetic example URL.

The [repository](https://github.com/606scat/perch) is public, MIT licensed, and has private vulnerability reporting enabled. [Perch 0.3.1](https://github.com/606scat/perch/releases/tag/v0.3.1) is a published normal release. Source commit `8f8dac6` and tag `v0.3.1` identify the patch; `00459af` publishes its matching signed feed after the assets became available. Earlier release assets were preserved.

All four assets were downloaded without GitHub authentication and matched the local packages byte for byte. SHA-256 checks passed. The downloaded DMG was mounted read-only; its app passed strict nested-code, stapled-ticket, Gatekeeper, version/build, and architecture checks. Its Applications link was present. The downloaded installer then fetched the latest public ZIP and installed build 4 in an isolated destination without creating owner or sample data.

| Published asset | Bytes |
| --- | ---: |
| Perch.dmg | 11,379,348 |
| Perch-macOS-universal.zip | 10,784,842 |
| install-perch.command | 7,313 |
| SHA256SUMS | 256 |

The downloaded feed matched the local XML. The archive and XML signatures were independently verified against the public key embedded in the app. The feed retains the prior version’s correct download URL. The native 0.3.0 → 0.3.1 update completed on this Mac, produced two exact local data backups, and relaunched the notarized build 4. Only one Perch process was running afterward.

[GitHub’s Mac checks](https://github.com/606scat/perch/actions/runs/34051005837) passed for the release source: behavior tests, release build, strict embedded-code verification, and whitespace. The public README’s icon, screenshots, download links, and installation copy were also inspected in the browser.

## Remaining device and integration checks

Intel execution, a first install on the recipient’s actual Mac, and permission retention on that Mac were not exercised. Existing 0.1/0.2 users install the DMG once because those versions predate the updater.

Physical world-clock slider manipulation, horizontal/multiple-display dragging, full VoiceOver traversal, every accent/theme combination, changing System appearance externally while running, background notifications, login startup, and Apple Reminders account operations remain device checks. No Reminders permissions or account tasks were changed. File Tray accepts local file/folder URLs; promised-file drags without a local URL are not implemented.

These limits do not prevent downloading or using the verified release, and the checks are not a guarantee against every possible defect.
