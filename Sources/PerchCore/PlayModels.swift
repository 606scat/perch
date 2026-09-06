import Foundation

public enum RelaxMode: String, Codable, CaseIterable, Sendable { case breathing = "Breathwork", relax = "Just relax" }
public enum AmbientSound: String, Codable, CaseIterable, Sendable {
    case rain, ocean, tones, brown
    public var title: String { switch self { case .rain: "Soft rain"; case .ocean: "Ocean"; case .tones: "Warm tones"; case .brown: "Brown noise" } }
}
public struct RelaxPreferences: Codable, Equatable, Sendable {
    public var mode: RelaxMode = .breathing
    public var minutes = 5
    public var soundEnabled = false
    public var sound: AmbientSound = .rain
    public var voiceEnabled = false
    public var volume = 0.25
    public init() {}
    enum CodingKeys: CodingKey { case mode, minutes, soundEnabled, sound, voiceEnabled, volume }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = RelaxMode(rawValue: try c.decodeIfPresent(String.self, forKey: .mode) ?? "") ?? .breathing
        minutes = max(1, min(mode == .breathing ? 5 : 60, try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 5))
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false
        sound = AmbientSound(rawValue: try c.decodeIfPresent(String.self, forKey: .sound) ?? "") ?? .rain
        voiceEnabled = try c.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? false
        volume = max(0, min(1, try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.25))
    }
}

public struct ColorSwatch: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var hex: String
    public init(hex: String) throws { self.hex = try ColorCode.normalize(hex) }
}
public enum ColorCode {
    public static func normalize(_ source: String) throws -> String {
        var value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard [3, 6].contains(value.count), value.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { throw PlayError.invalidColor }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        return "#" + value.uppercased()
    }
    public static func components(_ source: String) throws -> (red: Int, green: Int, blue: Int) {
        let normalized = try normalize(source)
        let value = UInt32(normalized.dropFirst(), radix: 16)!
        return (Int((value >> 16) & 255), Int((value >> 8) & 255), Int(value & 255))
    }
    public static func rgb(_ source: String) throws -> String {
        let c = try components(source); return "rgb(\(c.red), \(c.green), \(c.blue))"
    }
}

public struct TextStatistics: Equatable, Sendable {
    public var characters: Int
    public var words: Int
    public var lines: Int
    public init(_ text: String) {
        characters = text.count
        var wordCount = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, _, _, _ in wordCount += 1 }
        words = wordCount
        lines = text.isEmpty ? 0 : text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: .newlines).count
    }
}
public enum TextTransform: String, CaseIterable, Sendable {
    case original = "Original", upper = "UPPERCASE", lower = "lowercase", title = "Title Case", oneLine = "One line", uniqueLines = "Unique lines"
    public func apply(to text: String) -> String {
        switch self {
        case .original: return text
        case .upper: return text.uppercased()
        case .lower: return text.lowercased()
        case .title: return text.capitalized
        case .oneLine: return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        case .uniqueLines:
            var seen = Set<String>(); return text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: .newlines).filter { seen.insert($0).inserted }.joined(separator: "\n")
        }
    }
}

public enum Decisions {
    public static func options(from text: String) -> [String] {
        Array(text.components(separatedBy: .newlines).map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)) }.filter { !$0.isEmpty }.prefix(100))
    }
    public static func choose<T: RandomNumberGenerator>(from values: [String], using generator: inout T) -> String? { values.randomElement(using: &generator) }
}

public struct DrawingPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x.isFinite ? max(0, min(1, x)) : 0; self.y = y.isFinite ? max(0, min(1, y)) : 0 }
    public func distance(to other: DrawingPoint) -> Double { hypot(x - other.x, y - other.y) }
}
public struct DoodleStroke: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var points: [DrawingPoint]
    public var hex: String
    public init(points: [DrawingPoint], hex: String) { self.points = Array(points.prefix(400)); self.hex = (try? ColorCode.normalize(hex)) ?? "#075FB7" }
}
public struct Garden: Codable, Equatable, Sendable {
    public var points = 0
    public var lastWateredDay: String?
    public init() {}
    public var stage: Int { switch points { case ..<1: 0; case 1..<5: 1; case 5..<12: 2; case 12..<24: 3; default: 4 } }
    public var stageName: String { ["A little seed", "First sprout", "Growing", "Leafy", "Flourishing"][stage] }
    public func canWater(at date: Date, calendar: Calendar = .current) -> Bool { lastWateredDay != LocalDay.key(date, calendar: calendar) }
    @discardableResult public mutating func water(at date: Date, calendar: Calendar = .current) -> Bool {
        guard canWater(at: date, calendar: calendar) else { return false }
        lastWateredDay = LocalDay.key(date, calendar: calendar); points = min(100_000, min(100_000, max(0, points)) + 1); return true
    }
    public mutating func finishFocus(duration: TimeInterval) {
        guard duration.isFinite, duration > 0 else { return }
        points = min(100_000, min(100_000, max(0, points)) + max(1, min(12, Int(min(duration, 3600) / 300))))
    }
}

public struct PlayData: Codable, Equatable, Sendable {
    public var relax = RelaxPreferences()
    public var swatches: [ColorSwatch] = []
    public var qrText = ""
    public var textInput = ""
    public var decisionOptions = ""
    public var strokes: [DoodleStroke] = []
    public var garden = Garden()
    public init() {}
    enum CodingKeys: CodingKey { case relax, swatches, qrText, textInput, decisionOptions, strokes, garden }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relax = try c.decodeIfPresent(RelaxPreferences.self, forKey: .relax) ?? RelaxPreferences()
        swatches = try c.decodeIfPresent([ColorSwatch].self, forKey: .swatches) ?? []
        qrText = try c.decodeIfPresent(String.self, forKey: .qrText) ?? ""
        textInput = try c.decodeIfPresent(String.self, forKey: .textInput) ?? ""
        decisionOptions = try c.decodeIfPresent(String.self, forKey: .decisionOptions) ?? ""
        strokes = try c.decodeIfPresent([DoodleStroke].self, forKey: .strokes) ?? []
        garden = try c.decodeIfPresent(Garden.self, forKey: .garden) ?? Garden()
    }
}

public enum PlayError: LocalizedError {
    case invalidColor, qrTooLong, qrUnavailable, drawingFull
    public var errorDescription: String? {
        switch self {
        case .invalidColor: "Enter a color such as #47A8FF or #09F."
        case .qrTooLong: "Keep QR content under 1,500 UTF-8 bytes so it stays easy to scan."
        case .qrUnavailable: "The QR image couldn’t be created. Try a shorter message."
        case .drawingFull: "This doodle is full. Save it as an image, then clear the canvas to keep drawing."
        }
    }
}
