import Foundation

public struct ClipboardClip: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var text: String
    public var capturedAt: Date
    public init(text: String, now: Date = Date()) { self.text = text; capturedAt = now }
    public var title: String { String(text.split(whereSeparator: \.isNewline).first.map(String.init)?.prefix(80) ?? "Copied text") }
}

public struct Calculation: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var expression: String
    public var result: String
    public init(expression: String, result: String) { self.expression = expression; self.result = result }
}

public struct Milestone: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var title: String
    public var date: Date
    public init(title: String, date: Date) { self.title = title; self.date = date }
    public func days(from now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}

public enum LocalDay {
    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        var calendar = calendar
        // Gregorian date keys remain readable and don't change with display locale.
        if calendar.identifier != .gregorian { let zone = calendar.timeZone; calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

public struct DailyHabit: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var title: String
    public var completedDays: [String] = []
    public init(title: String) { self.title = title }
    public func completed(on date: Date, calendar: Calendar = .current) -> Bool { completedDays.contains(LocalDay.key(date, calendar: calendar)) }
    public mutating func toggle(on date: Date, calendar: Calendar = .current) {
        let day = LocalDay.key(date, calendar: calendar)
        if completedDays.contains(day) { completedDays.removeAll { $0 == day } }
        else { completedDays.append(day) }
    }
    public func streak(at now: Date, calendar: Calendar = .current) -> Int {
        let days = Set(completedDays)
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(LocalDay.key(cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }; cursor = yesterday
        }
        var result = 0
        while days.contains(LocalDay.key(cursor, calendar: calendar)) && result <= days.count {
            result += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }; cursor = previous
        }
        return result
    }
}

public struct BreathingSession: Equatable, Sendable {
    public var startedAt: Date
    public var duration: TimeInterval
    public init(minutes: Int, now: Date = Date()) { startedAt = now; duration = Double(max(1, min(5, minutes))) * 60 }
    public func remaining(at now: Date) -> TimeInterval { max(0, duration - max(0, now.timeIntervalSince(startedAt))) }
    public func inhale(at now: Date) -> Bool { max(0, now.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 10) < 4 }
    public func expansion(at now: Date) -> Double {
        let t = max(0, now.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 10)
        return t < 4 ? t / 4 : 1 - (t - 4) / 6
    }
}

public struct UtilityData: Codable, Equatable, Sendable {
    public var clips: [ClipboardClip] = []
    public var calculatorInput = ""
    public var calculations: [Calculation] = []
    public var clockZones: [String] = ["Asia/Jakarta", "Europe/London", "America/Los_Angeles"]
    public var milestones: [Milestone] = []
    public var habits: [DailyHabit] = []
    public init() {}
    enum CodingKeys: CodingKey { case clips, calculatorInput, calculations, clockZones, milestones, habits }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clips = try c.decodeIfPresent([ClipboardClip].self, forKey: .clips) ?? []
        calculatorInput = try c.decodeIfPresent(String.self, forKey: .calculatorInput) ?? ""
        calculations = try c.decodeIfPresent([Calculation].self, forKey: .calculations) ?? []
        let zones = try c.decodeIfPresent([String].self, forKey: .clockZones)
        if let zones { var seen = Set<String>(); clockZones = zones.filter { TimeZone(identifier: $0) != nil && seen.insert($0).inserted } }
        milestones = try c.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
        habits = try c.decodeIfPresent([DailyHabit].self, forKey: .habits) ?? []
    }
    public mutating func capture(_ text: String, now: Date = Date()) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw UtilityError.emptyClipboard }
        guard text.utf8.count <= 65_536 else { throw UtilityError.clipboardTooLarge }
        if let index = clips.firstIndex(where: { $0.text == text }) {
            var item = clips.remove(at: index); item.capturedAt = now; clips.insert(item, at: 0)
        } else { clips.insert(ClipboardClip(text: text, now: now), at: 0) }
        clips = Array(clips.prefix(30))
    }
}

public enum WorldCities {
    // Foundation's catalogue can retain older IANA spellings. Both spellings
    // should find the same city, with a valid modern identifier saved.
    private static let aliases = ["Asia/Calcutta": "Asia/Kolkata", "Asia/Katmandu": "Asia/Kathmandu", "Europe/Kiev": "Europe/Kyiv", "America/Godthab": "America/Nuuk", "Asia/Saigon": "Asia/Ho_Chi_Minh", "Asia/Rangoon": "Asia/Yangon"]
    public static let identifiers: [String] = Array(Set(TimeZone.knownTimeZoneIdentifiers.map { old in
        if let modern = aliases[old], TimeZone(identifier: modern) != nil { return modern }; return old
    })).sorted()
    public static func matching(_ query: String) -> [String] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return identifiers.filter { zone in
            let names = ([zone] + aliases.filter { $0.value == zone }.map(\.key)).joined(separator: " ").replacingOccurrences(of: "_", with: " ")
            return query.isEmpty || names.localizedCaseInsensitiveContains(query)
        }
    }
}

public enum UtilityError: LocalizedError {
    case emptyClipboard, clipboardTooLarge, invalidExpression, expressionTooLong, divisionByZero, nonFinite, incompatibleUnits
    public var errorDescription: String? {
        switch self {
        case .emptyClipboard: "Copy some text first, then keep it here."
        case .clipboardTooLarge: "That text is larger than 64 KB. Keep a smaller selection or save it as a file."
        case .invalidExpression: "Check the expression. Use numbers, parentheses, +, −, ×, ÷, ^, and %."
        case .expressionTooLong: "Keep calculations under 256 characters and 32 nested groups."
        case .divisionByZero: "You can’t divide by zero."
        case .nonFinite: "That result is outside the supported number range."
        case .incompatibleUnits: "Choose two units from the same category."
        }
    }
}
