import Testing
import AppKit
import SwiftUI
import PerchCore
@testable import Perch

@Test @MainActor func quitFlushSavesRapidEditsBeforeDebounceAndSurvivesRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    let store = AppStore(dataURLOverride: url, connectSystemServices: false)
    store.data.notes = [Note(text: "Latest text before quitting")]
    store.data.noteDraftTitle = "Unfinished title"
    store.data.preferences.theme = .light
    store.data.preferences.accent = .green
    #expect(store.flush())
    let reopened = AppStore(dataURLOverride: url, connectSystemServices: false)
    #expect(reopened.data.notes == store.data.notes)
    #expect(reopened.data.noteDraftTitle == "Unfinished title")
    #expect(reopened.data.preferences.theme == .light && reopened.data.preferences.accent == .green)
}

@Test @MainActor func failedQuitSaveReturnsFalseAndRetainsChangesForRetry() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    let store = AppStore(dataURLOverride: url, connectSystemServices: false)
    store.data.notes = [Note(text: "Never discard this pending change")]
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    #expect(!store.flush())
    #expect(store.error?.contains("Couldn’t save your changes") == true)
    #expect(store.data.notes.first?.text == "Never discard this pending change")
    try FileManager.default.removeItem(at: url)
    #expect(store.flush())
    #expect(try Persistence.load(from: url).notes == store.data.notes)
}

@Test @MainActor func accentTextKeepsContrastInLightAndDarkAppearances() throws {
    func luminance(_ color: NSColor, in appearance: NSAppearance) -> Double {
        var rgb: NSColor!
        appearance.performAsCurrentDrawingAppearance { rgb = color.usingColorSpace(.sRGB) }
        func channel(_ value: CGFloat) -> Double {
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.redComponent) + 0.7152 * channel(rgb.greenComponent) + 0.0722 * channel(rgb.blueComponent)
    }
    let light = try #require(NSAppearance(named: .aqua))
    let dark = try #require(NSAppearance(named: .darkAqua))
    for accent in PerchAccent.allCases {
        let lightValue = luminance(accent.nsColor, in: light)
        let darkValue = luminance(accent.nsColor, in: dark)
        #expect(1.05 / (lightValue + 0.05) >= 4.5)
        let background = luminance(NSColor(srgbRed: 25 / 255, green: 27 / 255, blue: 30 / 255, alpha: 1), in: dark)
        #expect((darkValue + 0.05) / (background + 0.05) >= 4.5)
        for (appearance, fill) in [(light, lightValue), (dark, darkValue)] {
            let foreground = luminance(NSColor(Palette.onAccent), in: appearance)
            #expect((max(foreground, fill) + 0.05) / (min(foreground, fill) + 0.05) >= 4.5)
        }
        #expect(darkValue > lightValue)
    }
}

@Test @MainActor func widgetRemovalUndoAndShortcutConflicts() {
    let store = AppStore(demo: true)
    let originalWidgets = store.data.preferences.widgets
    store.toggleWidget(.notes)
    #expect(!store.data.preferences.widgets.contains(.notes))
    #expect(!store.data.notes.isEmpty)
    store.undo()
    #expect(store.data.preferences.widgets == originalWidgets)
    let notes = WidgetShortcut(keyCode: 45, modifiers: 6144, display: "⌃⌥N")
    store.setShortcut(notes, for: .notes)
    store.setShortcut(notes, for: .focus)
    #expect(store.data.preferences.widgetShortcuts["notes"] == notes)
    #expect(store.data.preferences.widgetShortcuts["focus"] == nil)
    #expect(store.error?.contains("already opens Notes") == true)
    store.setShortcut(WidgetShortcut(keyCode: 49, modifiers: 6144, display: "⌃⌥Space"), for: .focus)
    #expect(store.error?.contains("Quick capture") == true)
    store.setShortcut(nil, for: .notes)
    #expect(store.data.preferences.widgetShortcuts["notes"] == nil)
}

@Test @MainActor func notesSnippetsFocusAndFileReferences() throws {
    let store = AppStore(demo: true)
    store.addNote("A useful note\nMore detail")
    let note = try #require(store.data.notes.first)
    store.updateNote(note.id, text: "Changed text")
    #expect(store.data.notes.first?.text == "Changed text")
    store.deleteNote(store.data.notes[0]); store.undo()
    #expect(store.data.notes.contains { $0.id == note.id })
    let initial = try #require(store.data.focus)
    store.startFocus(title: "Another task")
    #expect(store.data.focus == initial)
    store.toggleFocus(); #expect(store.data.focus?.isRunning == false)
    store.toggleFocus(); #expect(store.data.focus?.isRunning == true)
    store.stopFocus(); #expect(store.data.focus == nil)
    store.startFocus(title: "One clear task")
    #expect(store.section == .focus)
    #expect(store.data.focus?.title == "One clear task")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("A file 日本語.txt")
    try Data("Example file".utf8).write(to: file)
    store.addFiles([file, file])
    #expect(store.data.tray.count == 1)
    let item = try #require(store.data.tray.first)
    #expect(store.resolve(item).standardizedFileURL == file.standardizedFileURL)
    store.removeTray(item)
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(store.data.tray.isEmpty)
    store.undo(); #expect(store.data.tray.count == 1)
}

@MainActor final class TestDragInfo: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    init(_ pasteboard: NSPasteboard) { draggingPasteboard = pasteboard }
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    nonisolated var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 0
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    nonisolated override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}

@Test @MainActor func nativeFileDropOpensTrayAndAddsTheActualFile() throws {
    _ = NSApplication.shared
    let store = AppStore(demo: true)
    store.section = .notes; store.expanded = false
    var activated = false
    store.filesDropped = { activated = true }
    let host = FileDropHostingView(rootView: EmptyView(), store: store)
    #expect(host.registeredDraggedTypes.contains(.fileURL))
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("Perch-drop-\(UUID().uuidString).txt")
    try Data("Native drag smoke test".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.writeObjects([file as NSURL])
    let drag = TestDragInfo(pasteboard)
    #expect(host.draggingEntered(drag) == .copy)
    #expect(store.section == .tray)
    #expect(store.expanded && store.receivingFiles)
    #expect(host.prepareForDragOperation(drag))
    #expect(host.performDragOperation(drag))
    #expect(store.data.tray.first?.url == file)
    #expect(!store.receivingFiles && activated)
    #expect(FileManager.default.fileExists(atPath: file.path))
    store.storageLocked = true
    #expect(host.draggingEntered(drag).isEmpty)
    #expect(!host.performDragOperation(drag))
}

@Test @MainActor func compactNotesAllowRoomForTransientFeedback() {
    let store = AppStore(demo: true)
    store.data.notes = []; store.section = .notes; store.selectedNoteID = nil
    let idle = store.preferredPanelSize.height
    #expect(idle == 132)
    store.offerUndo("Note deleted") {}
    #expect(store.preferredPanelSize.height >= idle + 34)
    store.undo()
    #expect(store.preferredPanelSize.height == idle)
    store.showToast("Copied")
    #expect(store.preferredPanelSize.height >= idle + 44)
    store.error = "A recoverable error"
    #expect(store.preferredPanelSize.height >= idle + 44 + 84)
}

@Test @MainActor func menuBarKeepsWidgetsAvailableWhenDockIsHidden() {
    let delegate = AppDelegate()
    delegate.store = AppStore(demo: true)
    let menu = NSMenu()
    delegate.menuWillOpen(menu)
    #expect(menu.items.first?.title == "Hide dock")
    delegate.store.data.preferences.dockVisible = false
    delegate.menuWillOpen(menu)
    #expect(menu.items.first?.title == "Show dock")
    for widget in DockWidget.allCases { #expect(menu.items.contains { $0.representedObject as? String == widget.rawValue }) }
    #expect(menu.items.contains { $0.title == "Edit widgets & shortcuts…" })
    #expect(menu.items.contains { $0.title == "Pause focus" })
    #expect(menu.items.contains { $0.title == "Quit Perch" })
}

@Test @MainActor func widgetShortcutTogglesAndSwitchesWithoutLosingDrafts() {
    let store = AppStore(demo: true)
    store.expanded = false; store.data.noteDraftTitle = "Keep this draft"
    store.activateWidgetShortcut(.notes)
    #expect(store.expanded && store.section == .notes)
    store.activateWidgetShortcut(.notes)
    #expect(!store.expanded)
    store.activateWidgetShortcut(.notes)
    #expect(store.expanded && store.section == .notes)
    store.activateWidgetShortcut(.focus)
    #expect(store.expanded && store.section == .focus)
    #expect(store.data.noteDraftTitle == "Keep this draft")
    store.canDismissPanel = { false }
    store.activateWidgetShortcut(.focus)
    #expect(store.expanded)
}

@Test @MainActor func widgetEditorButtonTogglesWithoutClearingConfiguration() {
    let store = AppStore(demo: true)
    store.expanded = false
    let widgets = store.data.preferences.widgets
    store.togglePanel(.widgets)
    #expect(store.expanded && store.editingWidgets && store.section == .widgets)
    store.togglePanel(.widgets)
    #expect(!store.expanded && !store.editingWidgets)
    #expect(store.data.preferences.widgets == widgets)
}

@Test @MainActor func clockSlowsWhenPausedAndCatchesUpAfterSleep() throws {
    let store = AppStore(demo: true)
    #expect(store.clockInterval == 1)
    store.toggleFocus()
    #expect(store.clockInterval == 60)
    let paused = try #require(store.data.focus)
    store.tick(at: Date().addingTimeInterval(120))
    #expect(store.data.focus == paused)
    store.toggleFocus()
    #expect(store.clockInterval == 1)
    let end = try #require(store.data.focus?.endsAt)
    store.tick(at: end.addingTimeInterval(1))
    #expect(store.data.focus == nil)
    #expect(store.clockInterval == 60)
    #expect(store.toast?.hasPrefix("Focus complete") == true)
    store.data.priorityIDs = ["demo-1"]
    store.tick(at: Calendar.current.date(byAdding: .day, value: 1, to: end)!)
    #expect(store.data.priorityIDs.isEmpty)
}

@Test @MainActor func clockDoesNotKeepDiscardedStoresAlive() {
    weak var released: AppStore?
    do {
        let store = AppStore(demo: true)
        released = store
        #expect(released != nil)
    }
    #expect(released == nil)
}
