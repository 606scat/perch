# Perch

<!-- impeccable:product-schema 1 -->

## Platform
macOS (native desktop; the skill's mobile/web platform vocabulary does not describe this app).

## Stack
SwiftUI and AppKit, proposed earlier in this conversation and accepted when af asked to implement. Swift Package Manager, macOS 14 minimum. No external dependencies.

## Users
af and, optionally, his cofounder on an M1 Mac. Each installation has independent data and settings. No collaborative features.

## Product Purpose
A compact desktop utility for today's priorities, quick capture, and moving between projects without losing context.

## Capabilities and Constraints
- Apple Reminders backs tasks, due dates, recurring reminders, and alarms.
- Up to three daily priorities refer to existing reminder identifiers.
- Local notes, pinned snippets, project shortcuts, and a temporary file tray.
- Fourteen available widgets, with the original six enabled by default. A searchable picker and scrolling dock support larger collections.
- Explicit clipboard shelf, arithmetic calculator/history, six-category unit conversion, city clocks with meeting preview, named date countdowns, daily habits, guided breathing, and timed native Keep Awake.
- Clipboard capture is manual and skips source-marked private/temporary content. Keep Awake and breathing are temporary sessions that do not resume after quitting. No new accounts or network services are needed.
- A task-linked focus timer shows the task and time while collapsed.
- Global quick capture plus user-recorded shortcuts for individual widgets; deliberate, high-quality interaction sounds with mute and volume controls.
- Preserve originals when removing files from the tray. No automatic sharing, account access, or credential collection.
- Request system permissions only when the user enables the relevant feature.
- Format upgrades preserve an exact migration backup and prevent older apps from overwriting newer widget data.
- af created the private `606scat/perch` GitHub repository and requested an easy cofounder download and a repeatable update path that preserves local data. Deliver source and private release packages there; retain its private visibility. Public distribution and Developer ID notarization are separate work.

- Menu-bar access remains available with the screen dock hidden, with focus countdown, pause/resume, direct widget opening, and settings.

## Brand Commitments
Compact, smooth Mac utility inspired by nootch, Vinz's side dock, and Boring Notch. Restrained, tactile sound feedback. Perch is an explicitly provisional implementation name.

## Evidence on Hand
References inspected in the current conversation: https://x.com/dipxsyy/status/2096313337416200381 and https://x.com/hivinz_/status/2096195844798292232 . File tray reference: https://github.com/TheBoredTeam/boring.notch . Original implementation; no third-party source copied.

## Open Decisions
Final app name and icon. A Developer ID identity for standard distribution; the initial private build uses the owner's existing Apple Development certificate. Cofounder's macOS version, repository access, and on-device validation.
