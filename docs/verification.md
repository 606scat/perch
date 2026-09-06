# Verification — September 6, 2026

Native macOS development build. This report separates local checks, private release publication, and recipient-device validation. It does not claim notarization or public distribution.

## Automated checks

33 tests passed in the latest source test run:

- wall-clock focus countdown through sleep/restart; pause/resume; duplicate focus start protection; adaptive idle/running clock cadence, completion after a simulated wake, and timer ownership cleanup
- priority reset at local midnight, deduplication, and three-task bound
- atomic data round trip; corrupted and future-version data protection
- persisted unfinished note drafts and migration from older data
- safe project URL schemes
- preferences migration; widget order/unknown-ID handling
- appearance migration and persistence across all three themes and six accents; unknown-value fallback; adaptive accent text and solid-button foreground contrast of at least 4.5:1 in both native appearances
- widget removal, preserved data, and Undo restoring the original order
- per-widget shortcut persistence, physical-key comparison, duplicate/capture-shortcut rejection, and removal; repeated shortcut and widget-editor activation toggles the panel
- all four edges, external-display coordinates, dock position invariant while flyouts open, small flyout dimensions, bubble pointer alignment at screen clamps, space for transient feedback, and an 18-point reachable dock strip at all four edges on primary/external-display coordinates
- native Finder-style pasteboard file URLs, multi-file deduplication, spaces and Unicode, non-file rejection
- native drag destination registration, drag entry opening the tray, successful insertion of a real temporary file, preservation of its original, and locked-storage rejection
- note create/edit/delete/undo, file add/remove/undo, and focus state changes

## Live UI checks

Verified in the actual built app: compact dock and notes panel rendering, widget gallery, add/remove/Undo, notes creation and deletion confirmation, timer pause, shortcut recording and opening Notes while Perch is active, and the blue Reminders connection button. Test note was removed through its confirmation dialog. The Notes shortcut Control–Option–N remains configured from the keyboard check.

The final optimized release build and strict local signature verification passed. Live screenshots confirm the shared feature icons, compact Notes panel, and a contained Undo footer on the empty file tray. A temporary reference to the project README was added and removed through the UI; the original remains intact. Undo restoration is covered by automated tests. The footer capture is `.impeccable/review/tray-undo.png`.

## Remaining integration gates

The user confirmed physical file dropping and a widget shortcut opening from another foreground app during this session. Multi-display physical dragging, background notification delivery, login startup, and Apple Reminders account operations still need live verification. This agent did not grant Reminders permissions or change account tasks. The current release build shows the Connect state; do not infer current permission from an earlier build. No claim of zero possible defects or release readiness is made.

The current file tray accepts existing local file/folder URLs. Promised-file drags that have no local URL yet (some browser, Mail, or screenshot-thumbnail sources) are not implemented.

The independent finishing reviewer returned **ship** for the bounded verdict pass: feedback sizing, clamped pointer alignment, original widget order after Undo, tray Undo containment, and feature icon consistency were all resolved. This verdict covers those findings, not every possible app or integration scenario.

## Resource behavior

The optimized native app bundle is approximately 5.4 MB. A baseline 20-second paused-focus sample averaged 0.8% of one CPU core, with a 31 MB physical footprint. The clock now refreshes once per minute when idle or paused, and once per second during an active focus session, with timer tolerance. Daily priority normalization runs only when the day changes. Wake, activation, and clock changes refresh wall-clock state. Timer/task cleanup is covered by a store-lifetime regression test.

A subsequent 20-second sample during user interaction measured 1.45% CPU and a 28.5 MB physical footprint; because the interaction state differed, this does not establish a CPU reduction. Measurements are short observations on this Mac, not a long-session leak guarantee.

The final gallery uses a 400×460 panel with functional descriptions and grouped keyboard controls. Dock reveal/tuck uses 0.34/0.30-second easing, waits 3 seconds before tucking, and keeps the screen-edge gap in its tracking region. Independent final review returned **ship** at the inspected source/screenshot scope; physical hover timing, VoiceOver traversal, and multi-display movement remain device checks.

Final release sample after closing the gallery with focus paused: 20.01 seconds, CPU rounded to 0.0% of one core at `ps` timing resolution, physical footprint 27.0 MB, RSS stable at 88.44 MiB. The earlier baseline used the fully visible dock; this final sample uses the tucked dock. Physical footprint and RSS measure different things; RSS includes resident shared mappings. Raw final observations are in `.impeccable/review/performance-final.json`.

## Animation correction after user feedback

The user observed a blink instead of the slide. Both the macOS preference and the live AppKit API reported Reduce Motion enabled; the previous window-animation guard therefore skipped every slide. Perch now has its own persisted **Smooth dock motion** preference (enabled for the user's explicit request). The running Settings UI reports it checked while the system setting remains enabled. Shortcut/click opening also uses the animated path, and unchanged frame/opacity targets no longer restart transitions. The setting migration and disabled-value persistence are covered by the 26-test suite. Endpoint screenshots alone do not verify perceived animation smoothness.

## Appearance extension

The running optimized app was checked in Dark/blue/glass, Light/blue/glass, and Light/purple/solid configurations. Light/purple/solid survived restarting the app. Quick Capture visibly follows the chosen theme and purple accent. System mode was checked both at launch and when switching back from Light; it resolves to this Mac's current Dark appearance. Changing the operating system appearance while Perch remains open was not exercised.

Live QA caught a sheet retaining system blue and a stale window override when returning to System. Editor roots now explicitly inherit the selected accent, and NSApp.appearance is the sole theme authority. Notes uses semantic-color empty-field labels to avoid native placeholder dimming; action buttons use a fully opaque accent and contrasting foreground while pressed. Defaults were restored to Dark, Blue, and Glass background enabled after verification.

Colors are cached immutable native dynamic providers. Theme changes use the existing preference publisher, without polling. Solid mode removes the NSVisualEffectView instead of merely covering it. The earlier resource measurements predate this appearance extension; no additional CPU-reduction claim is made for these options.

Theme evidence is in `.impeccable/review/theme-*.png`; the latest test output is `.impeccable/review/tests-final.log`.

The independent appearance reviewer returned **ship** after confirming the pressed-action contrast, Notes empty-field labels, System transition, and sheet accent fixes. This verdict is limited to those scored appearance changes.

## Private release and update safety

The final source suite passed **33 tests**. New coverage checks older saved collections/preferences/bookmarks, exclusive ownership of the data file, installer/app exclusion, immediate quit-time saving before debounce, a failed save retaining in-memory edits for retry, and reopening saved notes/drafts/appearance choices. The earlier UI/theme evidence remains valid apart from the Settings version label, which now reads the bundle's actual version and build.

The real installer passed **8 isolated scenarios** under paths containing spaces and Unicode: first installation over existing data, fresh installation without seeded owner/sample data, same-build no-op, upgrade retaining the entire live data file byte-for-byte with verified data and prior-app backups, downgrade rejection, damaged archive rejection, concurrent-installer rejection, and unavailable-download failure. Test processes did not install over the user's app or use the user's data folder.

The optimized `0.1.0` build `1` package is approximately **3.4 MB zipped** and **9.3 MB unpacked**. Both arm64 and x86_64 slices target macOS 14.0. Runtime dependencies are system libraries/frameworks only. Strict code-signature verification passed with the existing Apple Development identity and hardened runtime; the package is not Developer ID signed or notarized.

The packaged app launched on this Mac. A normal Apple-event quit with Quick Capture open returned user-canceled and preserved the editor. After canceling that empty verification editor, normal quit succeeded. The user's actual saved JSON had the identical SHA-256 before launch and after quit. No test note or account task was added. This confirms that exercised restart path, not every possible future schema migration.

Remaining recipient gates: private-repository access, macOS 14+, first-open approval for this development build, and Reminders/notification consent on the cofounder's Mac. Intel execution and actual recipient installation were not exercised. An update preserves app-owned data; macOS permission retention is governed by signing identity and OS policy and is not guaranteed.

Release preparation, installer instructions, compatibility rules, backup recovery, and publication read-back are documented in `AGENTS.md`, `docs/INSTALL.md`, and `docs/RELEASING.md`. Build output, review captures, credentials, and local data are excluded from source delivery.

## Publication verified

Source commit `607c9bf` and tag `v0.1.0` were pushed to the existing private repository without replacing its history. [Perch v0.1.0](https://github.com/606scat/perch/releases/tag/v0.1.0) was published with the universal app ZIP, installer, and checksums. All three assets were downloaded from GitHub and matched their local counterparts byte-for-byte. The downloaded installer then successfully fetched the latest published release itself and installed it into an isolated temporary destination. This verifies the actual GitHub download path for the owner's authenticated account; the recipient still needs repository access.

The packaged app is running on the owner's Mac. No build, test, installer, or publication job remains active. This task does not need to remain open for future updates; follow `docs/RELEASING.md` for a new release and `docs/INSTALL.md` on the recipient's Mac.
