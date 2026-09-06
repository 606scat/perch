import Testing
import Foundation
import PerchCore
import Darwin

@Test func twoAppCopiesCannotOwnTheSameData() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("data.json")
    var original = AppData(); original.notes = [Note(text: "Keep this note")]
    try Persistence.save(original, to: url)
    var first: PersistenceLease? = try PersistenceLease(dataURL: url)
    #expect(first != nil)
    #expect(throws: PersistenceLease.LeaseError.self) { try PersistenceLease(dataURL: url) }
    #expect(try Persistence.load(from: url) == original)
    first = nil
    let next = try PersistenceLease(dataURL: url)
    withExtendedLifetime(next) { #expect(first == nil) }
}

@Test func activeInstallerPreventsAppOpeningItsData() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let lock = folder.appendingPathComponent(".update-lock")
    try FileManager.default.createDirectory(at: lock, withIntermediateDirectories: true)
    try String(getpid()).write(to: lock.appendingPathComponent("pid"), atomically: true, encoding: .utf8)
    #expect(throws: PersistenceLease.LeaseError.self) { try PersistenceLease(dataURL: folder.appendingPathComponent("data.json")) }
}

@Test func previousReleaseDataRetainsEveryUserCollectionAndPreference() throws {
    // Fixture predates appearance/dock-motion preferences and unfinished drafts.
    let fixture = #"""
    {"version":1,"notes":[{"id":"11111111-1111-1111-1111-111111111111","text":"Original note 日本語","updatedAt":800000000}],
    "snippets":[{"id":"22222222-2222-2222-2222-222222222222","title":"Reply","text":"Thanks!"}],
    "links":[{"id":"33333333-3333-3333-3333-333333333333","title":"Docs","destination":"https://example.com","project":"Work","bookmark":"AQID"}],
    "tray":[{"id":"44444444-4444-4444-4444-444444444444","url":"file:///tmp/original.txt","bookmark":"BAUG","addedAt":800000000}],
    "priorityIDs":["task-1"],"priorityDay":"2026-9-6",
    "focus":{"title":"Current task","reminderID":"task-1","duration":1500,"endsAt":900000000,"pausedRemaining":1500},
    "preferences":{"interactionSounds":false,"alertSounds":false,"interactionVolume":0.2,"alertVolume":0.4,"focusMinutes":45,
    "reminderListID":"chosen-list","dockEdge":"right","dockFraction":0.6,"dockDisplayID":123,
    "widgets":["notes","tray"],"widgetShortcuts":{"notes":{"keyCode":45,"modifiers":6144,"display":"⌃⌥N"}}}}
    """#
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("data.json")
    try Data(fixture.utf8).write(to: url)
    var data = try Persistence.load(from: url)
    #expect(data.notes.first?.text == "Original note 日本語")
    #expect(data.snippets.first?.text == "Thanks!")
    #expect(data.links.first?.bookmark == Data([1, 2, 3]))
    #expect(data.tray.first?.bookmark == Data([4, 5, 6]))
    #expect(data.priorityIDs == ["task-1"])
    #expect(data.focus?.reminderID == "task-1")
    #expect(data.preferences.reminderListID == "chosen-list")
    #expect(data.preferences.widgets == [.notes, .tray])
    #expect(data.preferences.widgetShortcuts["notes"]?.display == "⌃⌥N")
    #expect(data.preferences.dockEdge == .right)
    #expect(data.preferences.theme == .dark && data.preferences.accent == .blue)
    #expect(!data.preferences.interactionSounds && !data.preferences.alertSounds)
    data.preferences.theme = .light; data.noteDraftTitle = "Unfinished new note"
    try Persistence.save(data, to: url)
    #expect(try Persistence.load(from: url) == data)
}
