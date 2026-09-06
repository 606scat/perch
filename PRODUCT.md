# Perch

<!-- impeccable:product-schema 1 -->

## Platform
macOS (native desktop; the skill's mobile/web platform vocabulary does not describe this app).

## Stack
SwiftUI and AppKit, proposed earlier in this conversation and accepted when af asked to implement. Swift Package Manager, macOS 14 minimum. Sparkle 2.9.6 provides signed in-app updates.

## Users
Mac users who want quick tools at the screen edge. Each installation has independent data and settings. No collaborative features.

## Product Purpose
A compact desktop utility for today's priorities, quick capture, and moving between projects without losing context.

## Capabilities and Constraints
- Apple Reminders backs tasks, due dates, recurring reminders, and alarms.
- Up to three daily priorities refer to existing reminder identifiers.
- Local notes, pinned snippets, project shortcuts, and a temporary file tray.
- Twenty available widgets, with Notes, Today, Focus, File tray, Snippets, and Projects enabled by default. A searchable picker and scrolling dock support larger collections.
- Explicit clipboard shelf, arithmetic calculator/history, six-category unit conversion, city clocks with meeting preview, named date countdowns, daily habits, guided breathing, and timed native Keep Awake.
- Clipboard capture is manual and skips source-marked private/temporary content. Keep Awake and breathing are temporary sessions that do not resume after quitting. No new accounts or network services are needed.
- A task-linked focus timer shows remaining time and a short state label while collapsed; the full task title is available in the flyout and tooltip.
- Global quick capture plus user-recorded shortcuts for individual widgets; deliberate, high-quality interaction sounds with mute and volume controls.
- Preserve originals when removing files from the tray. No automatic sharing, account access, or credential collection.
- Request system permissions only when the user enables the relevant feature.
- Format upgrades preserve an exact migration backup and prevent older apps from overwriting newer widget data.
- The owner authorized public open-source distribution from `606scat/perch`, a drag-to-Applications DMG, and native in-app updates. Preserve existing local data and verify published downloads.
- Relax offers breathwork or a quiet session, four original ambient loops, and optional system speech. Color picker, QR generation, text tools, quick decisions, doodle, and a small garden extend the widget library.
- The library orders daily tools before playful ones; custom dock orders are preserved. Compact tiles use bounded labels or counts.

- Menu-bar access remains available with the screen dock hidden, with focus countdown, pause/resume, direct widget opening, and settings.

## Brand Commitments
Compact, smooth Mac utility inspired by nootch, Vinz's side dock, and Boring Notch. Restrained, tactile sound feedback. Perch is an explicitly provisional implementation name.

## Evidence on Hand
References inspected in the current conversation: https://x.com/dipxsyy/status/2096313337416200381 and https://x.com/hivinz_/status/2096195844798292232 . File tray reference: https://github.com/TheBoredTeam/boring.notch . Original implementation; no third-party source copied.

## Open Decisions
Developer ID signing and notarization require a usable Apple Developer account in Xcode. The public beta uses the existing Apple Development certificate until that account gate is resolved. Intel execution and installation on another Mac remain device checks.
