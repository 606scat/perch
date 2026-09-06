---
name: Perch
description: Compact native macOS widgets with adaptive themes, accents, and glass.
colors:
  accent: "#47A8FF"
  accent-light: "#075FB7"
  accent-purple: "#B495FF"
  accent-purple-light: "#7440BB"
  accent-pink: "#F58AB4"
  accent-pink-light: "#B52D64"
  accent-orange: "#F8AF62"
  accent-orange-light: "#9C5200"
  accent-green: "#78CD95"
  accent-green-light: "#26713D"
  accent-teal: "#66CCC1"
  accent-teal-light: "#00706B"
  foreground: "#F0F0F0"
  foreground-light: "#1E2228"
  secondary: "#ABB0B8"
  secondary-light: "#555C67"
  rule: "#FFFFFF"
  rule-light: "#000000"
  background: "#191B1E"
  background-light: "#F2F3F5"
  surface: "rgb(255 255 255 / 5.5%)"
  surface-light: "rgb(0 0 0 / 4.5%)"
  tile: "rgb(0 0 0 / 76%)"
  tile-light: "rgb(255 255 255 / 85%)"
  field: "rgb(0 0 0 / 34%)"
  field-light: "rgb(255 255 255 / 80%)"
  rail-tint: "rgb(0 0 0 / 36%)"
  rail-tint-light: "rgb(255 255 255 / 45%)"
  panel-tint: "rgb(0 0 0 / 30%)"
  panel-tint-light: "rgb(255 255 255 / 66%)"
  on-accent: "#101820"
  on-accent-light: "#FFFFFF"
  warning: "#FFBA70"
  warning-light: "#985000"
  error: "#FFBAA0"
  error-light: "#AE3030"
typography:
  title:
    fontFamily: "SF Pro"
    fontSize: "14pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro"
    fontSize: "13pt"
    fontWeight: 400
  label:
    fontFamily: "SF Pro"
    fontSize: "11pt"
    fontWeight: 400
  tile-title:
    fontFamily: "SF Pro"
    fontSize: "8pt"
    fontWeight: 600
  timer:
    fontFamily: "SF Mono"
    fontSize: "14pt"
    fontWeight: 500
rounded:
  field: "8pt"
  feedback: "10pt"
  tile: "12pt"
  gallery-card: "12pt"
  flyout: "15pt"
  rail: "16pt"
spacing:
  tile-inset: "5pt"
  rail-gap: "6pt"
  bubble-inset: "8pt"
  card-inset: "12pt"
  content-inset: "14pt"
components:
  dock-tile:
    backgroundColor: "{colors.tile}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.tile}"
    width: "52pt"
    height: "54pt"
    padding: "5pt"
  blue-action:
    textColor: "{colors.accent}"
    rounded: "{rounded.field}"
    padding: "9pt 12pt"
  note-field:
    rounded: "{rounded.field}"
    height: "25pt"
    padding: "0pt 8pt"
  feedback:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.feedback}"
    height: "40pt"
    padding: "0pt 12pt"
---

# Design System: Perch

## Overview

**Creative North Star: "A narrow strip of useful miniature widgets"**

Perch is a native macOS utility built with SwiftUI and AppKit. Its visual authority is the user's Vinz video and screenshot: match the slim charcoal glass dock, inset black tiles, electric blue accents, white system typography, miniature live contents, and small speech-bubble flyouts. The default remains Dark with Blue accent and glass enabled. User-selected Light or System appearance, six accent choices, and solid backgrounds adapt that same compact design; preserve its proportions and density.

The interface stays compact and tactile. Hover reveals the relevant tool without stealing keyboard focus; deliberate activation supports typing. Perch remains a provisional product name. The surface contract and reference provenance live in `docs/panel-brief.md` and `PRODUCT.md`.

**Key Characteristics:**

- Default charcoal glass and black inset tiles, with adaptive light and solid variants.
- Miniature live information and one selected accent, defaulting to electric blue.
- Small anchored bubbles with native desktop interaction.
- Shared vector widget artwork across dock, gallery, and empty states.

## Colors

The theme picker offers System, Light, and Dark; Dark is the preserved default. `NSApp.appearance` is the single appearance authority: System sets it to `nil`, Light uses Aqua, and Dark uses Dark Aqua. Do not add view-level `preferredColorScheme` overrides. Cached adaptive `NSColor` providers resolve semantic `Palette` colors and the selected accent against the effective native appearance.

Frontmatter base colors describe Dark; corresponding `-light` tokens describe Light. The accent token defaults to Blue. Purple, Pink, Orange, Green, and Teal are alternate user selections, each with light and dark values. Exactly one selected accent drives selection, progress, save actions, links, Undo, and editor control tint. `Appearance.swift` defines these colors; use `store.accentColor` rather than a fixed blue. All editor roots explicitly apply the selected accent to their controls.

Foreground, secondary text, rules, background, surfaces, tiles, fields, material tints, warning, error, and `onAccent` are semantic roles. Notes empty-field labels use `Palette.secondary` without native placeholder dimming; they preserve field accessibility and do not intercept clicks. Solid pressed actions and filled save controls use adaptive `Palette.onAccent` for readable contrast. Warning and destructive colors remain semantic exceptions, not additional brand accents.

Rail borders use `Palette.rule` at 17% opacity and 0.7pt; flyout borders use 18% and 0.7pt. Tile borders use the same role at 10% at rest and 28% on hover, with a 0.65pt stroke. Selection uses the selected accent at 85% and a 1.3pt stroke. These rules resolve to black in Light and white in Dark.

## Typography

Use SwiftUI system typography, resolved by macOS to the SF family. Use the monospaced system design for timers and the rounded system design for the Today count. No downloaded fonts are required.

The main panel defaults to 13pt. Page headings use 14pt semibold, Widgets uses 15pt semibold, and the compact Notes and Focus headings use 12pt semibold. Notes fields and rows use 11pt, with a 12pt editor. Supporting flyout text generally uses 10–12pt. The dock deliberately uses miniature 6.5–9pt labels; its Today count is 22pt. These miniature sizes belong to the rail's summary views, not the editing surfaces. Text line limits keep tiles compact; flyout lists scroll and longer descriptions wrap.

## Layout

All dimensions here are native logical points, not web CSS physical points. The vertical rail is 64pt wide, with 6pt padding and spacing. Each tile is 52 × 54pt with 5pt internal padding. A grip precedes the widgets and an add control follows them. Horizontal placement changes the stack direction while preserving upright tile contents; the horizontal rail is 66pt high. Rail length follows the number of enabled widgets. The dock tucks to an 18pt peek strip on all four screen edges. Its full native window frame includes the gap to the screen edge so hover stays continuous; the child rail retains its 64pt vertical or 66pt horizontal geometry and clips within the container.

The dock and flyout are independent floating AppKit panels. Most flyouts prefer 320pt width; Settings uses 380pt and Widgets uses 400pt. Preferred content heights are state-dependent:

| Surface | Height before feedback and warnings |
| --- | --- |
| Focus, idle / active | 156pt / 104pt |
| Today, disconnected / authorized | 340pt / 450pt |
| Notes, empty / list / editor | 132pt / 280pt / 340pt |
| File tray | 330pt |
| Snippets / Projects | 360pt |
| Settings | 590pt |
| Widgets | 460pt |

Use the screen's visible frame to constrain the flyout. Preserve the pointer's alignment with the selected tile while clamping the bubble and its pointer near screen edges. Content sizing follows the resulting panel frame. Flyout content has an outer 8pt inset and ordinarily 14pt internal padding. Widgets uses a two-column grid with 8pt gaps, 10pt card padding, and 6pt internal vertical spacing.

Feedback reserves an additional 52pt: a 40pt row, 4pt above, and 8pt below. It sits inside the bubble with 8pt horizontal inset, allowing Undo or a two-line toast without covering the content or clipping against the pointer. Errors and storage protection reserve their own additional height.

## Elevation & Depth

Glass background is enabled by default. `PerchSurface` uses active `NSVisualEffectView` HUD material with behind-window blending and adaptive rail or panel tint. Dark uses black at 36% on the rail and 30% on flyouts; Light uses white at 45% and 66%. Turning Glass background off removes the visual-effect view and fills with `Palette.background`. Both AppKit panels retain native shadows; adaptive rule borders and translucent surface fills define their inner structure. Preserve the native glass and solid options without changing geometry.

Flyouts fade and move 8pt outward from the dock when opening. AppKit uses 260ms to open and 180ms to close, with control points `(0.22, 1, 0.36, 1)`. Native dock and flyout transitions follow Perch’s persisted “Smooth dock motion” setting, enabled by default. Its Settings description explains that it overrides macOS Reduce Motion for these window slides; unrelated SwiftUI motion continues to follow the system preference. Tile hover uses a 1.025 scale and 150ms ease-out. Rail changes use a 300ms spring with damping fraction 0.88; rail animation also observes Reduce Motion. These are extracted behaviors, not a claim that every local animation is reduced-motion gated. Dock reveal uses 340ms and tuck uses 300ms with cubic control points `(0.25, 0.1, 0.25, 1)`; both use the app’s “Smooth dock motion” preference and become immediate when that preference is disabled. The rail waits three seconds outside active interaction before tucking. Accessibility-command reveal stays latched until pointer interaction or an outside click releases it.

## Shapes

The rail uses a continuous 16pt rounded rectangle; tiles use continuous 12pt corners. Flyouts have 15pt body corners with an 8pt inset and a small triangular pointer facing the dock edge. Fields and accent actions use 8pt corners, feedback 10pt, and gallery cards 12pt. Circular controls carry add/remove and the Notes save arrow.

`WidgetGlyph` is the sole shared artwork for the six widget identities. Paths are authored on a 24pt grid and rendered with a 1.65pt stroke, round caps, and round joins. Reuse those paths at each required size. Native SF Symbols remain appropriate for generic actions such as settings, copy, delete, and share. Finder supplies file icons.

## Components

**Dock visibility and clock:** Hovering the peek strip reveals the rail. Retraction waits while a flyout or protected interaction is active. Accessibility exposes the tucked rail as “Show Perch dock” and keeps command-triggered reveal available for use. The clock refreshes every 60 seconds when idle or paused and every second during running focus, with 3s and 0.1s timer tolerance respectively. Wake, activation, and clock-change handling catch up from actual elapsed time.

**Dock tile:** A miniature live summary in an adaptive tile container. Selection adds the chosen accent border; hover brightens the border and subtly scales the tile. The full tile has a named accessibility button action. Dragging reorders widgets. Removing a widget retains its data and timer; Undo restores its original position, bounded by the current widget count.

**Flyout:** Hover enters after 140ms; pointer exit dismisses after a 320ms grace period. Hover does not activate the app or steal keyboard focus. Clicking or invoking a shortcut activates editing. Repeating the current widget shortcut toggles its flyout closed. A command-opened flyout remains reachable before pointer entry. Outside clicks and Escape dismiss; active sheets, dialogs, file receiving, Quick Look, and editing receive the protections implemented in `PerchApp.swift`. Do not add a tiny close button.

**Widget gallery:** Compact two-column cards use a 20pt `WidgetGlyph`, 12pt semibold title, and 22pt circular add/remove control in one header row. Descriptions use 10pt text. The shortcut recorder is a single compact trailing group: keyboard icon and key label stay together at intrinsic width and 19pt height. Cards use shared widget artwork rather than full `DockTile` previews. Hidden widgets remain accessible through their registered shortcuts. Settings and Done live in the compact header.

**Notes fields:** Two adaptive 25pt fields capture the title and optional description. Focus draws an accent outline on the title field. A 25pt circular selected-accent arrow with `Palette.onAccent` artwork saves; empty or whitespace-only titles disable saving. Return submits. Existing notes appear in a scrolling list; editor changes save automatically. Deletion uses a native confirmation alert and temporary Undo.

**Accent action:** `BlueActionStyle` uses 12pt medium text, 12pt horizontal and 9pt vertical padding, an 8pt corner radius, a faint accent fill, and a 0.7pt accent border. Pressing changes the 10% fill to solid selected accent and switches text to `Palette.onAccent`; disabled styling uses secondary text and weaker fill and border. Other controls use native bordered and bordered-prominent styles with the selected accent.

**Feedback footer:** Undo takes precedence over a toast. Keep the complete row within the flyout's rounded body and reserve its height in panel sizing. The selected-accent Undo action remains visible alongside a two-line message. Removing a tray item only removes its reference; its original file stays in place.

**Appearance settings:** A segmented System/Light/Dark picker, six named accent circles, and Glass background toggle. The selected accent has a checkmark, selection ring, and accessible selected value. Theme, accent, and glass choices persist independently; defaults remain Dark, Blue, and glass on.

**File tray:** The empty target uses a dashed rounded boundary, shared tray glyph, and Choose files action. Native file dragging opens the tray before release. Populated rows use Finder icons, names, availability text, Quick Look, sharing, and removal. Unavailable originals disable file-dependent actions.

## Do's and Don'ts

- Do preserve the user's pinned Vinz material, proportions, density, and compact flyout direction.
- Do reuse `DockTile`, `WidgetGlyph`, semantic `Palette` colors, the selected accent, native material, and native controls.
- Do let `NSApp.appearance` govern the app and preserve readable light, dark, glass, and solid variants.
- Do size feedback with the panel and keep Undo inside the bubble.
- Do preserve keyboard shortcuts, pointer dismissal protections, accessible labels, and menu-bar access with the dock hidden.
- Don't replace the native desktop surface with a mobile or web layout.
- Don't enlarge the rail into a dashboard or replace its live miniature tiles with generic navigation icons.
- Don't introduce a second widget icon family or rasterize the vector paths.
- Don't treat removing a widget or a tray reference as deleting the user's underlying data.

Recorded from the local implementation and reviewed captures in `.impeccable/review/`: `dock.png`, `notes-shortcut.png`, `widgets.png`, and `tray-undo.png`. These record the baseline geometry. Appearance captures are `theme-dark-settings.png`, `theme-light-settings.png`, `theme-light-purple-solid.png`, and `theme-light-capture.png`. Documentation records the implemented System fallback policy; external OS appearance changes are not claimed as verified here. Captures are not distribution or cofounder-device validation.
