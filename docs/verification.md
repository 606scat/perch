# Verification — September 7, 2026

Perch 0.3.0, build 3, data format 3. This report separates automated checks, observations in the native app, public delivery, and checks that still require another device.

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
| Updates | Settings displays manual update checking and optional automatic checks. Public-feed verification is recorded below. |
| Restart and data | The owner’s prior JSON has an exact migration backup. Saved collections and unrelated preferences were preserved. Known QA text/drawing inputs were removed under the data lease while the app was quit; the original six widgets and Dark appearance were restored. |

The prior running 0.2.0 app froze at the local day change: an Objective-C calendar notification entered SwiftUI publication from a background queue. The captured thread sample identified the deadlock. Version 0.3.0 explicitly hops that notification to the main actor and includes the regression test above.

Earlier still-applicable checks include the owner’s physical file drop and cross-app global shortcut, note editing, focus pause, Quick Capture, removal/Undo, quit cancellation with an open editor, multiple dock appearances, actual Keep Awake assertion start/stop, and live creation/deletion of a temporary habit and countdown.

The fresh independent reviewer inspected fourteen valid final captures and found no material visual corrections. Its sole documentation finding was corrected in DESIGN.md and the design sidecar; the reviewer scored that fix resolved with disposition **ship**. The review did not exercise audio playback or perform an update installation.

## Resource behavior

Widgets use the existing shared clock: once per minute while idle or paused, once per second during a timed focus/Relax session, with wall-clock catch-up after wake. Breathing animation runs only in its visible panel, at 30 frames per second, and respects Reduce Motion. Ambient playback uses one looped native player; speech initializes only when requested. Clipboard capture remains manual. QR rendering is debounced. Sparkle owns update scheduling without an additional poller.

## Release checks

The universal app contains arm64 and x86_64 slices targeting macOS 14. Its embedded Sparkle framework is included, with toolchain-only runtime search paths removed. Developer ID signing, strict nested-code verification, stapled-ticket validation, and Gatekeeper assessment passed for the final export: **accepted — Notarized Developer ID**. The DMG contains that exact notarized app; this release’s outer disk image is not separately notarized.

The public-history audit inspected all five earlier commits and their reachable content. Credential-pattern and sensitive-path scans found no matching secrets or local data. The current source scan likewise found none. Build output, review captures, signing credentials, and local data are excluded. The two README screenshots contain only the native Relax UI and a synthetic example URL.

Public publication and anonymous asset/update-feed read-back are pending in this checkpoint; the delivery record will be updated after those checks.

## Remaining device and integration checks

Intel execution, a first install on the recipient’s actual Mac, a complete older-to-newer Sparkle replacement, and permission retention across that upgrade were not exercised. Existing 0.1/0.2 users install the DMG once because those versions predate the updater.

Physical world-clock slider manipulation, horizontal/multiple-display dragging, full VoiceOver traversal, every accent/theme combination, changing System appearance externally while running, background notifications, login startup, and Apple Reminders account operations remain device checks. No Reminders permissions or account tasks were changed. File Tray accepts local file/folder URLs; promised-file drags without a local URL are not implemented.

These limits do not prevent downloading or using the verified release, and the checks are not a guarantee against every possible defect.
