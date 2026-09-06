import Foundation
import Testing
@testable import PerchCore

@Test func colorCodesNormalizeAndRejectAmbiguousValues() throws {
    #expect(try ColorCode.normalize(" #a0f \n") == "#AA00FF")
    #expect(try ColorCode.rgb("a0f") == "rgb(170, 0, 255)")
    for invalid in ["", "#1234", "##fff", "#12gg12", "１２３", "#ffffff00"] {
        #expect(throws: (any Error).self) { try ColorCode.normalize(invalid) }
    }
}
@Test func textToolsKeepUnicodeAndHandleCRLF() {
    let input = "Hello world\r\nHello world\r\n👩🏽‍💻"
    #expect(TextStatistics(input).lines == 3)
    #expect(TextStatistics("👩🏽‍💻").characters == 1)
    #expect(TextStatistics("").words == 0 && TextStatistics("").lines == 0)
    #expect(TextTransform.uniqueLines.apply(to: input) == "Hello world\n👩🏽‍💻")
    #expect(TextTransform.oneLine.apply(to: " A\n\t B ") == "A B")
    #expect(TextTransform.upper.apply(to: "Hello") == "HELLO")
    #expect(input == "Hello world\r\nHello world\r\n👩🏽‍💻")
}
@Test func decisionsBoundChoicesAndOnlyReturnSuppliedOptions() {
    #expect(Decisions.options(from: "\n tea\n \ncoffee ") == ["tea", "coffee"])
    #expect(Decisions.options(from: Array(repeating: "choice", count: 110).joined(separator: "\n")).count == 100)
    #expect(Decisions.options(from: String(repeating: "x", count: 200))[0].count == 120)
    var random = SystemRandomNumberGenerator()
    #expect(Decisions.choose(from: [], using: &random) == nil)
    for _ in 0..<40 { #expect(["tea", "coffee"].contains(Decisions.choose(from: ["tea", "coffee"], using: &random)!)) }
}
@Test func gardenRewardsEachDayAndCompletedFocusWithBounds() {
    var garden = Garden(); var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = Date(timeIntervalSince1970: 1_800_000_000)
    let first = garden.water(at: day, calendar: calendar); #expect(first)
    #expect(!garden.water(at: day.addingTimeInterval(1), calendar: calendar) && garden.points == 1)
    let next = garden.water(at: calendar.date(byAdding: .day, value: 1, to: day)!, calendar: calendar); #expect(next)
    garden.finishFocus(duration: 1500); #expect(garden.points == 7 && garden.stage == 2)
    garden.finishFocus(duration: .infinity); #expect(garden.points == 7)
    garden.points = Int.max; garden.finishFocus(duration: 300); #expect(garden.points == 100_000 && garden.stage == 4)
}
@Test func relaxDefaultsModesAndWallClockAreStable() throws {
    let defaults = try JSONDecoder().decode(RelaxPreferences.self, from: Data("{}".utf8))
    #expect(defaults.minutes == 5 && !defaults.soundEnabled && !defaults.voiceEnabled)
    let unknown = try JSONDecoder().decode(RelaxPreferences.self, from: Data(#"{"mode":"unknown","sound":"unknown","volume":4,"minutes":900}"#.utf8))
    #expect(unknown.mode == .breathing && unknown.sound == .rain && unknown.volume == 1 && unknown.minutes == 5)
    let start = Date(); let relax = BreathingSession(minutes: 30, now: start, mode: .relax)
    #expect(relax.duration == 1800 && relax.remaining(at: start.addingTimeInterval(1900)) == 0)
    #expect(BreathingSession(minutes: 30, mode: .breathing).duration == 300)
}
@Test func formatTwoMigrationPreservesUtilitiesAndCustomOrder() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("data.json")
    var prior = AppData(); prior.version = 2; prior.play = nil
    prior.preferences.widgets = [.garden, .notes, .calculator]
    prior.notes = [Note(text: "Keep every word")]; prior.noteDraftDetail = "Still writing"
    prior.utilities?.calculatorInput = "12 * 2"; prior.utilities?.habits = [DailyHabit(title: "Walk")]
    try Persistence.save(prior, to: url); let bytes = try Data(contentsOf: url)
    let migrated = try Persistence.load(from: url)
    #expect(migrated.version == 3 && migrated.play == PlayData())
    #expect(migrated.utilities == prior.utilities && migrated.notes == prior.notes && migrated.noteDraftDetail == prior.noteDraftDetail)
    #expect(migrated.preferences == prior.preferences)
    let backup = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Migration Backups"), includingPropertiesForKeys: nil)
    #expect(backup.count == 1)
    #expect(try Data(contentsOf: backup[0]) == bytes)
    #expect(try Data(contentsOf: url) == bytes)
    prior.preferences.widgets = [.focus, .today, .notes, .tray, .snippets, .projects]
    try Persistence.save(prior, to: url)
    #expect(try Persistence.load(from: url).preferences.widgets == DockWidget.defaults)
}
@Test func updateBackupIsExactAndFailureDoesNotTouchLiveData() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("Perch/data.json"); let data = AppData()
    try Persistence.save(data, to: url); let bytes = try Data(contentsOf: url)
    let target = try UpdateBackup.create(dataURL: url, backupRoot: root.appendingPathComponent("Backups"))
    #expect(try Data(contentsOf: target) == bytes)
    let blocker = root.appendingPathComponent("file"); try Data("blocked".utf8).write(to: blocker)
    #expect(throws: (any Error).self) { try UpdateBackup.create(dataURL: url, backupRoot: blocker) }
    #expect(try Data(contentsOf: url) == bytes)
}
