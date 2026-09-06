# Desktop dock

Mode: Operate. Visual authority is the user's Vinz video and supplied screenshot, reiterated September 6: match the slim glass dock and compact hover panels one to one. Native implementation retains the approved personal productivity features.

## Direction contract

THESIS: A narrow strip of useful miniature widgets that opens only the tool under the cursor.

OWN-WORLD: Translucent charcoal glass rail, inset black rounded tiles, electric blue outlines and controls, white SF typography, miniature live contents, and small speech-bubble flyouts. The screenshot is the authority for material, proportions, density, and motion vocabulary.

STORY: Hover a miniature widget, act in its compact flyout, move away to dismiss. Drag the grip to any screen edge. Use the plus to add, remove, and reorder widgets.

FIRST VIEWPORT: A 64-point vertical rail, six 52-by-54-point miniature widgets, compact grip and add control. Notes opens a 320-by-132-point bubble when empty with a title field, optional description, and blue circular arrow. Existing notes expand into a scrollable list; editing expands further. Horizontal edges rotate the rail layout, preserving widget orientation.

FORM: Native AppKit panels with SwiftUI content, fixed rail and independently animated flyout. Click activates editing; hover does not steal keyboard focus. Keyboard shortcuts and a persistent menu-bar item provide alternate entry points. Each widget has a recordable global shortcut. Menu-bar commands hide/show the screen dock without quitting. Actual pointer exit dismisses after a short grace period, except while typing or using dialogs. Shortcut opening remains reachable before pointer entry, and repeating the shortcut toggles it closed. No tiny close button. Native file dragging opens the tray before release.

FINISH: Finish review, verdict, DESIGN.md and asset provenance accompany the local build.

## Scope

Personal and cofounder use through the private GitHub repository. Apple Reminders access is opt-in and scoped in app behavior to a chosen writable list. Notes, snippets, and shortcuts work without access. File tray holds references to originals. Original synthesized sounds; no sampled audio. Preview mode is separate from saved user data. Private install/update packages preserve local data; public distribution and notarization remain separate delivery choices.
