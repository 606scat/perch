import Foundation
import Testing
@testable import PerchCore

private func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
private func calendar(_ zone: String) -> Calendar {
    var result = Calendar(identifier: .gregorian); result.timeZone = TimeZone(identifier: zone)!; return result
}

@Test func citySearchAcceptsModernAndLegacyNamesWithoutDuplicateChoices() {
    #expect(WorldCities.matching("Kolkata") == ["Asia/Kolkata"])
    #expect(WorldCities.matching("Calcutta") == ["Asia/Kolkata"])
    #expect(WorldCities.matching(" Kathmandu ") == ["Asia/Kathmandu"])
    #expect(WorldCities.matching("Kyiv") == ["Europe/Kyiv"])
    #expect(WorldCities.matching("no-such-city").isEmpty)
    #expect(Set(WorldCities.identifiers).count == WorldCities.identifiers.count)
    #expect(WorldCities.identifiers.allSatisfy { TimeZone(identifier: $0) != nil })
}

@Test func calculatorPrecedenceFractionsScientificNotationAndFailures() throws {
    let cases: [(String, Double)] = [("2+3*4", 14), ("(2+3)×4", 20), ("-2^2", -4), ("2^3^2", 512), ("2^-2", 0.25), ("200*15%", 30), (".5 + 1.5", 2), ("1e3÷2", 500), ("−(3+4)", -7)]
    for (input, expected) in cases { #expect(try Calculator.evaluate(input) == expected) }
    for input in ["", "1/0", "0/0", "(2+3", "1..2", "2+", "sqrt(4)", "1e309", "10^999", "(-1)^.5", "2;echo hi", String(repeating: "(", count: 40) + "1" + String(repeating: ")", count: 40), String(repeating: "1", count: 257)] {
        #expect(throws: (any Error).self) { try Calculator.evaluate(input) }
    }
    #expect(Calculator.format(-0.0) == "0")
}

@Test func conversionOffsetsFractionalUnitsAndRoundTrips() throws {
    #expect(abs(try ConversionUnit.convert(32, from: "°F", to: "°C")) < 0.000_001)
    #expect(abs(try ConversionUnit.convert(100, from: "°C", to: "°F") - 212) < 0.000_001)
    #expect(abs(try ConversionUnit.convert(0, from: "K", to: "°C") + 273.15) < 0.000_001)
    #expect(try ConversionUnit.convert(1, from: "MiB", to: "B") == 1_048_576)
    #expect(try ConversionUnit.convert(1, from: "MB", to: "B") == 1_000_000)
    for source in ConversionUnit.all {
        for target in ConversionUnit.all where target.category == source.category {
            let converted = try ConversionUnit.convert(123.456, from: source.id, to: target.id)
            #expect(abs(try ConversionUnit.convert(converted, from: target.id, to: source.id) - 123.456) < 0.000_001)
        }
    }
    #expect(throws: (any Error).self) { try ConversionUnit.convert(1, from: "m", to: "kg") }
    #expect(throws: (any Error).self) { try ConversionUnit.convert(.infinity, from: "m", to: "cm") }
}

@Test func habitsRespectLocalDaysDSTUndoAndUnfinishedToday() {
    let cal = calendar("America/New_York")
    let first = instant("2026-03-07T17:00:00Z")
    let second = instant("2026-03-08T16:00:00Z")
    let third = instant("2026-03-09T16:00:00Z")
    var habit = DailyHabit(title: "Walk")
    habit.toggle(on: first, calendar: cal); habit.toggle(on: second, calendar: cal)
    #expect(habit.streak(at: third, calendar: cal) == 2)
    habit.toggle(on: third, calendar: cal)
    #expect(habit.streak(at: third, calendar: cal) == 3)
    habit.toggle(on: second, calendar: cal)
    #expect(habit.streak(at: third, calendar: cal) == 1)
    #expect(!habit.completed(on: second, calendar: cal))
    #expect(LocalDay.key(instant("2026-03-09T02:00:00Z"), calendar: cal) == "2026-03-08")
    var buddhist = Calendar(identifier: .buddhist); buddhist.timeZone = cal.timeZone
    #expect(LocalDay.key(first, calendar: buddhist) == "2026-03-07")
}

@Test func countdownUsesCalendarDaysAcrossDSTAndPastDates() {
    let cal = calendar("America/New_York")
    let item = Milestone(title: "Launch", date: instant("2026-03-09T01:00:00Z"))
    #expect(item.days(from: instant("2026-03-08T04:00:00Z"), calendar: cal) == 1)
    #expect(item.days(from: instant("2026-03-08T16:00:00Z"), calendar: cal) == 0)
    #expect(item.days(from: instant("2026-03-09T16:00:00Z"), calendar: cal) == -1)
}

@Test func clipboardDeduplicatesRetainsExactTextAndBoundsStorage() throws {
    var data = UtilityData(); let text = "  One\nTwo 🎉  "
    try data.capture(text); let id = data.clips[0].id
    try data.capture("Other"); try data.capture(text)
    #expect(data.clips.count == 2 && data.clips.first?.id == id && data.clips.first?.text == text)
    for index in 0..<40 { try data.capture("Item \(index)") }
    #expect(data.clips.count == 30 && data.clips.first?.text == "Item 39")
    #expect(throws: (any Error).self) { try data.capture(" \n ") }
    #expect(throws: (any Error).self) { try data.capture(String(repeating: "🎉", count: 16_385)) }
}

@Test func breathingUsesElapsedTimeAndClampsDuration() {
    let start = instant("2026-09-06T12:00:00Z")
    let session = BreathingSession(minutes: 1, now: start)
    #expect(session.inhale(at: start.addingTimeInterval(3)))
    #expect(!session.inhale(at: start.addingTimeInterval(4)))
    #expect(session.expansion(at: start.addingTimeInterval(4)) == 1)
    #expect(session.expansion(at: start.addingTimeInterval(7)) == 0.5)
    #expect(session.remaining(at: start.addingTimeInterval(500)) == 0)
    #expect(session.remaining(at: start.addingTimeInterval(-5)) == 60)
    #expect(BreathingSession(minutes: 999).duration == 300)
}

@Test func formatOneMigrationBacksUpExactlyAndPreservesEveryCollection() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    var old = AppData(); old.version = 1; old.utilities = nil
    old.notes = [Note(text: "Keep my note")]; old.noteDraftTitle = "Draft"; old.noteDraftDetail = "Unfinished"
    old.snippets = [Snippet(title: "Useful", text: "Exact content")]
    old.preferences.widgets = [.projects, .notes]; old.preferences.accent = .pink; old.preferences.theme = .light
    old.preferences.widgetShortcuts = ["notes": WidgetShortcut(keyCode: 45, modifiers: 6144, display: "⌃⌥N")]
    try Persistence.save(old, to: url)
    let source = try Data(contentsOf: url)
    var expected = old; expected.version = 3; expected.utilities = UtilityData()
    let migrated = try Persistence.load(from: url)
    #expect(migrated == expected)
    #expect(try Data(contentsOf: url) == source)
    let backups = directory.appendingPathComponent("Migration Backups")
    let files = try FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
    #expect(try Data(contentsOf: files[0]) == source)
    try Persistence.save(migrated, to: url)
    #expect(try Persistence.load(from: url) == expected)
    #expect(try FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil).count == 1)
}

@Test func utilityDataRoundTripAndUnknownFormatsCannotBeSilentlyLost() throws {
    var data = AppData(); try data.utilities?.capture("Saved clipboard")
    data.utilities?.calculatorInput = "(2+3)*4"; data.utilities?.calculations = [Calculation(expression: "2+2", result: "4")]
    data.utilities?.clockZones = ["Asia/Kathmandu"]; data.utilities?.milestones = [Milestone(title: "Trip", date: Date())]
    var habit = DailyHabit(title: "Read"); habit.toggle(on: Date()); data.utilities?.habits = [habit]
    data.preferences.widgets = DockWidget.allCases
    #expect(try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(data)) == data)
    let filtered = try JSONDecoder().decode(UtilityData.self, from: Data(#"{"clockZones":["Asia/Jakarta","Bad/Zone","Asia/Jakarta"]}"#.utf8))
    #expect(filtered.clockZones == ["Asia/Jakarta"])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    data.version = 99; try Persistence.save(data, to: url); let bytes = try Data(contentsOf: url)
    #expect(throws: (any Error).self) { try Persistence.load(from: url) }
    #expect(try Data(contentsOf: url) == bytes)
}
