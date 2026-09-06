import Testing
import AppKit
import IOKit.pwr_mgt
import PerchCore
@testable import Perch

private final class FakePowerAssertions: PowerAssertionBackend {
    var made: [(Bool, TimeInterval, IOPMAssertionID)] = []
    var released: [IOPMAssertionID] = []
    var failDisplay = false
    func create(display: Bool, duration: TimeInterval) throws -> IOPMAssertionID {
        if display && failDisplay { throw NSError(domain: "Test", code: 1) }
        let id = IOPMAssertionID(made.count + 1); made.append((display, duration, id)); return id
    }
    func release(_ id: IOPMAssertionID) { released.append(id) }
}

@Test @MainActor func keepAwakeStopsOnExpiryFailureAndDeinitWithoutDuplicateAssertions() throws {
    let backend = FakePowerAssertions(); let now = Date()
    var controller: AwakeController? = AwakeController(backend: backend)
    try controller!.start(minutes: 15, display: true, now: now)
    try controller!.start(minutes: 180, display: true, now: now)
    #expect(backend.made.count == 2 && backend.made[0].0 == false && backend.made[1].0 == true)
    #expect(backend.made.allSatisfy { $0.1 == 900 })
    controller!.expire(at: now.addingTimeInterval(899)); #expect(controller!.endsAt != nil)
    controller!.expire(at: now.addingTimeInterval(900)); #expect(controller!.endsAt == nil && backend.released == [1, 2])
    backend.failDisplay = true
    #expect(throws: (any Error).self) { try controller!.start(minutes: 1, display: true) }
    #expect(controller!.endsAt == nil && backend.released == [1, 2, 3])
    try controller!.start(minutes: 1, display: false)
    controller = nil
    #expect(backend.released == [1, 2, 3, 4])
}

@Test @MainActor func utilityMutationsUndoAndPersistThroughRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    let store = AppStore(dataURLOverride: url, connectSystemServices: false)
    store.data.preferences.interactionSounds = false
    store.addHabit("  Walk daily  "); let habit = try #require(store.utilities.habits.first)
    store.toggleHabit(habit.id); store.renameHabit(habit.id, title: "Walk outside")
    #expect(store.utilities.habits[0].completed(on: Date()) && store.utilities.habits[0].title == "Walk outside")
    let complete = store.utilities.habits[0]; store.removeHabit(complete); store.undo()
    #expect(store.utilities.habits == [complete])
    let milestone = Milestone(title: "Launch", date: Date()); store.saveMilestone(milestone)
    store.removeMilestone(milestone); store.undo(); #expect(store.utilities.milestones == [milestone])
    try store.utilities.capture("Keep this"); let clip = store.utilities.clips[0]
    store.removeClip(clip); store.undo(); #expect(store.utilities.clips == [clip])
    for value in 1...25 { store.utilities.calculatorInput = "\(value)*2"; #expect(store.calculate() == String(value * 2)) }
    #expect(store.utilities.calculations.count == 20)
    #expect(store.calculate() == "50" && store.utilities.calculations.count == 20)
    store.data.preferences.widgets = DockWidget.allCases
    #expect(store.flush())
    let reopened = AppStore(dataURLOverride: url, connectSystemServices: false)
    #expect(reopened.utilities == store.utilities && reopened.data.preferences.widgets == DockWidget.allCases)
    #expect(reopened.awake.endsAt == nil && reopened.breathingSession == nil)
}

@Test @MainActor func failedMigrationBackupLocksWritesAndKeepsOriginalBytes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    var old = AppData(); old.version = 1; old.utilities = nil; old.notes = [Note(text: "Must survive a backup failure")]
    try Persistence.save(old, to: url)
    let original = try Data(contentsOf: url)
    // A file where the backup directory should be makes the migration fail.
    try Data("Occupied".utf8).write(to: directory.appendingPathComponent("Migration Backups"))
    let store = AppStore(dataURLOverride: url, connectSystemServices: false)
    #expect(store.storageLocked && store.error != nil)
    store.data.notes = [Note(text: "This must never replace the old file")]
    // A read-only launch can still quit; flush deliberately performs no write.
    #expect(store.flush())
    #expect(try Data(contentsOf: url) == original)
}

@Test @MainActor func clipboardRequiresTextAndHonorsPrivatePasteboardMarkers() throws {
    let store = AppStore(demo: true)
    let board = NSPasteboard(name: .init("Perch-tests-\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    board.setString("Explicitly kept", forType: .string)
    store.captureClipboard(from: board); #expect(store.utilities.clips.first?.text == "Explicitly kept")
    for type in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"] {
        board.clearContents(); board.setString("Private content", forType: .string)
        board.setData(Data(), forType: .init(type)); store.captureClipboard(from: board)
        #expect(store.utilities.clips.count == 1 && store.error?.contains("private or temporary") == true)
    }
    board.clearContents(); store.captureClipboard(from: board)
    #expect(store.utilities.clips.count == 1)
}

@Test @MainActor func newWidgetSelectionAndOverflowWorkAtEveryEdge() {
    let store = AppStore(demo: true)
    store.data.preferences.widgets = DockWidget.allCases; store.dockLengthLimit = 420
    for edge in DockEdge.allCases {
        store.data.preferences.dockEdge = edge
        #expect(edge.isVertical ? store.dockSize.height == 420 : store.dockSize.width == 420)
        for widget in DockWidget.allCases {
            store.expanded = false; store.activateWidgetShortcut(widget)
            #expect(store.expanded && store.section == widget.section)
            store.widgetOffsets = [widget: 200]
            #expect(store.hoveredWidgetOffset == 200)
            #expect(store.preferredPanelSize.width > 0 && store.preferredPanelSize.height > 0)
        }
    }
    store.data.preferences.widgets = DockWidget.defaults; store.data.preferences.dockEdge = .left
    #expect(store.dockSize == CGSize(width: 64, height: 414))
}

@Test @MainActor func breathingCompletesAfterSleepAndRestoresIdleClock() {
    let store = AppStore(demo: true); store.data.focus = nil
    let now = Date(); store.breathingSession = BreathingSession(minutes: 1, now: now)
    store.section = .breathing; #expect(store.clockInterval == 1)
    store.tick(at: now.addingTimeInterval(61))
    #expect(store.breathingSession == nil && store.clockInterval == 60)
    #expect(store.toast == "Relax session complete")
}

@Test func worldClockUsesDateSpecificOffsetsAndFractionalTimeZones() {
    let winter = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
    let summer = ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z")!
    #expect(ClockReading(zone: "Europe/London", date: winter).offset == "UTC+0:00")
    #expect(ClockReading(zone: "Europe/London", date: summer).offset == "UTC+1:00")
    #expect(ClockReading(zone: "Asia/Kathmandu", date: winter).time == "17:45")
    #expect(ClockReading(zone: "Asia/Kolkata", date: winter).offset == "UTC+5:30")
    #expect(ClockReading(zone: "America/Los_Angeles", date: winter).offset == "UTC−8:00")
}
