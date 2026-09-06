import Foundation
import AppKit
import CoreGraphics
import Testing
@testable import PerchCore

@Test func appearancePreferencesMigrateAndPersist() throws {
    let older = try JSONDecoder().decode(Preferences.self, from: Data("{\"interactionSounds\":false}".utf8))
    #expect(older.theme == .dark && older.accent == .blue && older.glassBackground)
    #expect(!older.interactionSounds)
    for theme in PerchTheme.allCases {
        for accent in PerchAccent.allCases {
            var preferences = older
            preferences.theme = theme; preferences.accent = accent; preferences.glassBackground = false
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
            #expect(restored == preferences)
        }
    }
    let unknown = try JSONDecoder().decode(Preferences.self, from: Data("{\"theme\":\"future\",\"accent\":\"future\",\"focusMinutes\":45}".utf8))
    #expect(unknown.theme == .dark && unknown.accent == .blue && unknown.focusMinutes == 45)
}

@Test func explicitDockMotionPreferenceMigratesAndPersists() throws {
    var preferences = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
    #expect(preferences.smoothDockMotion)
    preferences.smoothDockMotion = false
    let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
    #expect(!restored.smoothDockMotion)
}

@Test func tuckedDockKeepsAReachableStripOnEveryDisplayEdge() {
    for screen in [CGRect(x: 0, y: 24, width: 1440, height: 876), CGRect(x: -1920, y: -100, width: 1920, height: 1080)] {
        for edge in DockEdge.allCases {
            let size = edge.isVertical ? CGSize(width: 64, height: 414) : CGSize(width: 402, height: 66)
            for fraction in [0.0, 0.5, 1.0] {
                let full = DockGeometry.frame(edge: edge, fraction: fraction, visible: screen, expanded: false, compactSize: size)
                let peek = DockGeometry.peekFrame(full: full, edge: edge, visible: screen)
                #expect(screen.contains(peek))
                if edge.isVertical { #expect(peek.width == 18 && peek.minY == full.minY && peek.height == full.height) }
                else { #expect(peek.height == 18 && peek.minX == full.minX && peek.width == full.width) }
                switch edge {
                case .left: #expect(peek.minX == screen.minX)
                case .right: #expect(peek.maxX == screen.maxX)
                case .top: #expect(peek.maxY == screen.maxY)
                case .bottom: #expect(peek.minY == screen.minY)
                }
            }
        }
    }
}

@Test func focusUsesWallClockAcrossSleepAndRestart() throws {
    let now = Date(timeIntervalSince1970: 1000)
    let session = FocusSession(title: "Deep work", minutes: 25, now: now)
    let restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
    #expect(restored.remaining(at: now.addingTimeInterval(1200)) == 300)
    #expect(restored.remaining(at: now.addingTimeInterval(1800)) == 0)
}

@Test func pausedTimerDoesNotCountAwayTime() {
    let start = Date(timeIntervalSince1970: 1000)
    var session = FocusSession(title: "Work", minutes: 25, now: start)
    session.pause(at: start.addingTimeInterval(300))
    #expect(session.remaining(at: start.addingTimeInterval(3600)) == 1200)
    session.resume(at: start.addingTimeInterval(3600))
    session.resume(at: start.addingTimeInterval(3900))
    #expect(session.remaining(at: start.addingTimeInterval(3900)) == 900)
}

@Test func prioritiesResetAtLocalMidnightAndDeduplicate() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
    let before = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 23, minute: 59))!
    var data = AppData()
    data.normalizePriorities(now: before, calendar: calendar)
    data.priorityIDs = ["a", "a", "b", "c", "d"]
    data.normalizePriorities(now: before, calendar: calendar)
    #expect(data.priorityIDs == ["a", "b", "c"])
    data.normalizePriorities(now: before.addingTimeInterval(120), calendar: calendar)
    #expect(data.priorityIDs.isEmpty)
}

@Test func storageRoundTripAndCorruptionFailsWithoutOverwrite() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    var data = AppData(); data.notes = [Note(text: "A note\nwith unicode: 日本語")]
    data.snippets = [Snippet(title: "Command", text: "echo $HOME")]
    try Persistence.save(data, to: url)
    #expect(try Persistence.load(from: url) == data)
    let broken = Data("{broken".utf8)
    try broken.write(to: url)
    #expect(throws: (any Error).self) { try Persistence.load(from: url) }
    #expect(try Data(contentsOf: url) == broken)
}

@Test func newerDataVersionIsNotSilentlyDowngraded() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    var future = AppData(); future.version = 99
    try Persistence.save(future, to: url)
    #expect(throws: PersistenceError.self) { try Persistence.load(from: url) }
}

@Test func projectShortcutsRejectExecutableSchemes() {
    for destination in ["javascript:alert(1)", "data:text/html,hello", "ssh://host", "https://", "a shell command"] {
        #expect(ProjectLink(title: "Link", destination: destination, project: "Work").safeURL == nil)
    }
    #expect(ProjectLink(title: "Docs", destination: "https://developer.apple.com", project: "Work").safeURL != nil)
    #expect(ProjectLink(title: "App", destination: "file:///Applications/Notes.app", project: "Work").safeURL?.isFileURL == true)
}

@Test func olderPreferencesMigrateWithoutLosingSoundChoices() throws {
    let old = Data(#"{"interactionSounds":false,"focusMinutes":45}"#.utf8)
    let prefs = try JSONDecoder().decode(Preferences.self, from: old)
    #expect(!prefs.interactionSounds)
    #expect(prefs.focusMinutes == 45)
    #expect(prefs.dockEdge == .left)
    #expect(prefs.widgets == DockWidget.allCases)
}

@Test func widgetsIgnoreUnknownIDsAndDuplicatesWhilePreservingOrder() throws {
    let saved = Data(#"{"widgets":["notes","future-widget","notes","focus"]}"#.utf8)
    let prefs = try JSONDecoder().decode(Preferences.self, from: saved)
    #expect(prefs.widgets == [.notes, .focus])
    let empty = try JSONDecoder().decode(Preferences.self, from: Data(#"{"widgets":[]}"#.utf8))
    #expect(empty.widgets.isEmpty)
}

@Test func dockStaysOnScreenAndFlyoutDoesNotMoveIt() {
    for screen in [CGRect(x: 0, y: 25, width: 1440, height: 875), CGRect(x: -1920, y: -100, width: 1920, height: 1080), CGRect(x: 0, y: 25, width: 1024, height: 640)] {
        for edge in DockEdge.allCases {
            let size = edge.isVertical ? CGSize(width: 76, height: 470) : CGSize(width: 470, height: 76)
            for fraction in [0.0, 0.35, 1.0] {
                let compact = DockGeometry.frame(edge: edge, fraction: fraction, visible: screen, expanded: false, compactSize: size)
                #expect(screen.contains(compact))
                for offset in [CGFloat(63), CGFloat(390)] {
                    let layout = DockGeometry.layout(edge: edge, fraction: fraction, visible: screen, compactSize: size, panelSize: CGSize(width: 420, height: 590), expanded: true, widgetOffset: offset)
                    let restoredDock = CGRect(x: layout.window.minX + layout.dock.minX, y: layout.window.maxY - layout.dock.maxY, width: layout.dock.width, height: layout.dock.height)
                    #expect(abs(restoredDock.minX - compact.minX) < 0.001)
                    #expect(abs(restoredDock.minY - compact.minY) < 0.001)
                    #expect(screen.contains(layout.window))
                    #expect(!layout.dock.intersects(layout.content))
                }
                let point = CGPoint(x: compact.midX, y: compact.midY)
                let recovered = DockGeometry.fraction(for: point, edge: edge, visible: screen, compactSize: size)
                #expect(abs(recovered - fraction) < 0.001)
            }
        }
    }
}

@Test func draggingSelectsNearestEdgeOnAnExternalDisplay() {
    let screen = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
    #expect(DockGeometry.nearestEdge(to: CGPoint(x: -1910, y: 500), in: screen) == .left)
    #expect(DockGeometry.nearestEdge(to: CGPoint(x: -8, y: 500), in: screen) == .right)
    #expect(DockGeometry.nearestEdge(to: CGPoint(x: -900, y: 1070), in: screen) == .top)
    #expect(DockGeometry.nearestEdge(to: CGPoint(x: -900, y: 5), in: screen) == .bottom)
}

@Test func compactFlyoutsKeepTheirRequestedHeight() {
    let screen = CGRect(x: 0, y: 24, width: 1440, height: 876)
    for edge in DockEdge.allCases {
        let dock = edge.isVertical ? CGSize(width: 64, height: 414) : CGSize(width: 402, height: 66)
        for height in [104.0, 132.0, 340.0, 590.0] {
            let layout = DockGeometry.layout(edge: edge, fraction: 0.4, visible: screen, compactSize: dock,
                panelSize: CGSize(width: 320, height: height), expanded: true, widgetOffset: 172)
            #expect(abs(layout.content.height - height) < 0.001)
            #expect(screen.contains(layout.window))
        }
    }
}

@Test func unfinishedNoteSurvivesRestart() throws {
    var data = AppData()
    data.noteDraftTitle = "A thought to finish"
    data.noteDraftDetail = "Details stay here while switching widgets"
    let restored = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(data))
    #expect(restored.noteDraftTitle == data.noteDraftTitle)
    #expect(restored.noteDraftDetail == data.noteDraftDetail)
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as? [String: Any])
    object.removeValue(forKey: "noteDraftTitle"); object.removeValue(forKey: "noteDraftDetail")
    let older = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(older.noteDraftTitle == nil)
    #expect(older.noteDraftDetail == nil)
}

@Test func widgetShortcutsPersistAndMatchPhysicalKeys() throws {
    var preferences = Preferences()
    let shortcut = WidgetShortcut(keyCode: 45, modifiers: 6144, display: "⌃⌥N")
    preferences.widgetShortcuts[DockWidget.notes.rawValue] = shortcut
    let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
    #expect(restored.widgetShortcuts["notes"] == shortcut)
    #expect(shortcut.matches(WidgetShortcut(keyCode: 45, modifiers: 6144, display: "same key")))
    #expect(!shortcut.matches(WidgetShortcut(keyCode: 45, modifiers: 4096, display: "⌃N")))
    #expect(try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8)).widgetShortcuts.isEmpty)
}

@Test @MainActor func finderFileDropsDecodeMultipleURLsAndRejectWebLinks() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let first = URL(fileURLWithPath: "/tmp/A file with spaces.txt")
    let second = URL(fileURLWithPath: "/tmp/日本語.png")
    pasteboard.writeObjects([first as NSURL, second as NSURL, first as NSURL])
    #expect(FileDropDecoder.urls(from: pasteboard) == [first, second])
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(string: "https://example.com")! as NSURL])
    #expect(FileDropDecoder.urls(from: pasteboard).isEmpty)
    pasteboard.clearContents(); pasteboard.setString("some ordinary text", forType: .string)
    #expect(FileDropDecoder.urls(from: pasteboard).isEmpty)
}

@Test func bubblePointerTracksWidgetWhenFlyoutIsClamped() {
    let screen = CGRect(x: 0, y: 24, width: 1440, height: 876)
    for edge in DockEdge.allCases {
        let dock = edge.isVertical ? CGSize(width: 64, height: 414) : CGSize(width: 402, height: 66)
        for fraction in [0.0, 1.0] {
            for offset in [52.0, 352.0] {
                let layout = DockGeometry.layout(edge: edge, fraction: fraction, visible: screen, compactSize: dock,
                    panelSize: CGSize(width: 320, height: 590), expanded: true, widgetOffset: offset)
                let desired = edge.isVertical ? layout.dock.minY + offset - layout.content.minY : layout.dock.minX + offset - layout.content.minX
                let limit = edge.isVertical ? layout.content.height : layout.content.width
                #expect(abs(layout.pointerOffset - max(24, min(limit - 24, desired))) < 0.001)
            }
        }
    }
}
