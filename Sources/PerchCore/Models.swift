import Foundation
import CoreGraphics

public struct Note: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var text: String
    public var updatedAt = Date()
    public init(text: String = "") { self.text = text }
    public var title: String { text.split(separator: "\n").first.map(String.init) ?? "Untitled note" }
}

public struct Snippet: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var title: String
    public var text: String
    public init(title: String, text: String) { self.title = title; self.text = text }
}

public struct ProjectLink: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var title: String
    public var destination: String
    public var project: String
    public var bookmark: Data?
    public init(title: String, destination: String, project: String, bookmark: Data? = nil) {
        self.title = title; self.destination = destination; self.project = project; self.bookmark = bookmark
    }
    public var safeURL: URL? {
        guard let url = URL(string: destination), let scheme = url.scheme?.lowercased(),
              ["https", "http", "file"].contains(scheme) else { return nil }
        if scheme != "file", url.host?.isEmpty != false { return nil }
        return url
    }
}

public struct TrayItem: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var url: URL
    public var bookmark: Data?
    public var addedAt = Date()
    public init(url: URL, bookmark: Data? = nil) { self.url = url; self.bookmark = bookmark }
}

public struct FocusSession: Codable, Equatable, Sendable {
    public var title: String
    public var reminderID: String?
    public var duration: TimeInterval
    public var endsAt: Date?
    public var pausedRemaining: TimeInterval
    public init(title: String, reminderID: String? = nil, minutes: Int, now: Date = Date()) {
        self.title = title; self.reminderID = reminderID
        duration = TimeInterval(max(1, min(minutes, 180)) * 60)
        pausedRemaining = duration; endsAt = now.addingTimeInterval(duration)
    }
    public func remaining(at now: Date = Date()) -> TimeInterval {
        max(0, endsAt.map { $0.timeIntervalSince(now) } ?? pausedRemaining)
    }
    public mutating func pause(at now: Date = Date()) {
        pausedRemaining = remaining(at: now); endsAt = nil
    }
    public mutating func resume(at now: Date = Date()) {
        guard endsAt == nil, pausedRemaining > 0 else { return }
        endsAt = now.addingTimeInterval(pausedRemaining)
    }
    public var isRunning: Bool { endsAt != nil }
}

public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case left, right, top, bottom
    public var isVertical: Bool { self == .left || self == .right }
}

public enum DockWidget: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus, today, notes, tray, snippets, projects
    case clipboard, calculator, converter, clocks, countdowns, habits, breathing, awake
    case colors, qr, textTools, decisions, doodle, garden
    public static let defaults: [DockWidget] = [.notes, .today, .focus, .tray, .snippets, .projects]
    public static let libraryOrder: [DockWidget] = [.notes, .today, .focus, .tray, .clipboard, .snippets, .projects, .calculator, .converter, .clocks, .awake, .habits, .countdowns, .colors, .qr, .textTools, .breathing, .decisions, .doodle, .garden]
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .focus: "Focus"; case .today: "Today"; case .notes: "Notes"; case .tray: "File tray"; case .snippets: "Snippets"; case .projects: "Projects"
        case .clipboard: "Clipboard"; case .calculator: "Calculator"; case .converter: "Converter"; case .clocks: "World clock"
        case .countdowns: "Countdowns"; case .habits: "Habits"; case .breathing: "Relax"; case .awake: "Keep awake"
        case .colors: "Color picker"; case .qr: "QR code"; case .textTools: "Text tools"; case .decisions: "Quick decisions"; case .doodle: "Doodle"; case .garden: "Tiny garden"
        }
    }
    public var tileTitle: String {
        switch self { case .tray: "Files"; case .clipboard: "Clipboard"; case .calculator: "Calc"; case .clocks: "Clocks"; case .countdowns: "Dates"; case .awake: "Awake"; case .colors: "Colors"; case .decisions: "Decide"; case .garden: "Garden"; case .textTools: "Text"; default: title }
    }
}

public struct DockLayout: Sendable {
    public var window: CGRect
    public var dock: CGRect
    public var content: CGRect
    public var pointerOffset: CGFloat = 0
}

public enum DockGeometry {
    /// Keep a small, reachable strip inside the usable screen on every edge.
    public static func peekFrame(full: CGRect, edge: DockEdge, visible: CGRect, thickness: CGFloat = 18) -> CGRect {
        var frame = full
        if edge.isVertical {
            frame.size.width = max(1, min(full.width, thickness))
            frame.origin.x = edge == .left ? visible.minX : visible.maxX - frame.width
        } else {
            frame.size.height = max(1, min(full.height, thickness))
            frame.origin.y = edge == .bottom ? visible.minY : visible.maxY - frame.height
        }
        return frame
    }
    public static func frame(edge: DockEdge, fraction: Double, visible: CGRect, expanded: Bool, compactSize: CGSize? = nil) -> CGRect {
        let gap: CGFloat = 8
        let compact = compactSize ?? (edge.isVertical ? CGSize(width: 76, height: 242) : CGSize(width: 340, height: 48))
        let size = expanded ? CGSize(width: min(480, visible.width - 2 * gap), height: min(680, visible.height - 2 * gap)) : compact
        let fraction = CGFloat(max(0, min(1, fraction.isFinite ? fraction : 0.5)))
        let x: CGFloat
        let y: CGFloat
        if edge.isVertical {
            let centerY = visible.maxY - gap - compact.height / 2 - fraction * max(0, visible.height - compact.height - 2 * gap)
            x = edge == .left ? visible.minX + gap : visible.maxX - size.width - gap
            y = min(visible.maxY - size.height - gap, max(visible.minY + gap, centerY - size.height / 2))
        } else {
            let centerX = visible.minX + gap + compact.width / 2 + fraction * max(0, visible.width - compact.width - 2 * gap)
            x = min(visible.maxX - size.width - gap, max(visible.minX + gap, centerX - size.width / 2))
            y = edge == .top ? visible.maxY - size.height - gap : visible.minY + gap
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
    public static func layout(edge: DockEdge, fraction: Double, visible: CGRect, compactSize: CGSize, panelSize: CGSize, expanded: Bool, widgetOffset: CGFloat) -> DockLayout {
        let dock = frame(edge: edge, fraction: fraction, visible: visible, expanded: false, compactSize: compactSize)
        guard expanded else { return DockLayout(window: dock, dock: CGRect(origin: .zero, size: dock.size), content: .zero) }
        let width = min(panelSize.width, visible.width - (edge.isVertical ? compactSize.width + 24 : 16))
        let height = min(panelSize.height, visible.height - (edge.isVertical ? 16 : compactSize.height + 24))
        let size = CGSize(width: max(1, width), height: max(1, height))
        let anchorX = dock.minX + widgetOffset
        let anchorY = dock.maxY - widgetOffset
        let x: CGFloat, y: CGFloat
        if edge.isVertical {
            x = edge == .left ? dock.maxX + 8 : dock.minX - size.width - 8
            y = max(visible.minY + 8, min(visible.maxY - size.height - 8, anchorY - size.height / 2))
        } else {
            x = max(visible.minX + 8, min(visible.maxX - size.width - 8, anchorX - size.width / 2))
            y = edge == .top ? dock.minY - size.height - 8 : dock.maxY + 8
        }
        let content = CGRect(origin: CGPoint(x: x, y: y), size: size)
        let window = dock.union(content)
        func local(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX - window.minX, y: window.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        let desiredPointer = edge.isVertical ? content.maxY - anchorY : anchorX - content.minX
        let limit = edge.isVertical ? content.height : content.width
        let pointer = max(24, min(limit - 24, desiredPointer))
        return DockLayout(window: window, dock: local(dock), content: local(content), pointerOffset: pointer)
    }
    public static func nearestEdge(to point: CGPoint, in visible: CGRect) -> DockEdge {
        let choices: [(DockEdge, CGFloat)] = [(.left, abs(point.x - visible.minX)), (.right, abs(visible.maxX - point.x)), (.top, abs(visible.maxY - point.y)), (.bottom, abs(point.y - visible.minY))]
        return choices.min { $0.1 < $1.1 }!.0
    }
    public static func fraction(for point: CGPoint, edge: DockEdge, visible: CGRect, compactSize: CGSize? = nil) -> Double {
        let compactLength: CGFloat = compactSize.map { edge.isVertical ? $0.height : $0.width } ?? (edge.isVertical ? 242 : 340)
        let available = max(1, (edge.isVertical ? visible.height : visible.width) - compactLength - 16)
        let offset = edge.isVertical ? visible.maxY - point.y - compactLength / 2 - 8 : point.x - visible.minX - compactLength / 2 - 8
        return Double(max(0, min(1, offset / available)))
    }
}

public struct WidgetShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var display: String
    public init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.display = display
    }
    public func matches(_ other: WidgetShortcut) -> Bool { keyCode == other.keyCode && modifiers == other.modifiers }
}

public enum PerchTheme: String, Codable, CaseIterable, Sendable { case system, light, dark }
public enum PerchAccent: String, Codable, CaseIterable, Sendable { case blue, purple, pink, orange, green, teal }

public struct Preferences: Codable, Equatable, Sendable {
    public var theme: PerchTheme = .dark
    public var accent: PerchAccent = .blue
    public var glassBackground = true
    public var interactionSounds = true
    public var alertSounds = true
    public var interactionVolume: Double = 0.35
    public var alertVolume: Double = 0.7
    public var focusMinutes = 25
    public var reminderListID: String?
    public var dockVisible = true
    public var smoothDockMotion = true
    public var dockEdge: DockEdge = .left
    public var dockFraction: Double = 0.35
    public var dockDisplayID: UInt32?
    public var widgets: [DockWidget] = DockWidget.defaults
    public var widgetShortcuts: [String: WidgetShortcut] = [:]
    public init() {}
    enum CodingKeys: String, CodingKey { case interactionSounds, alertSounds, interactionVolume, alertVolume, focusMinutes, reminderListID, dockEdge, dockFraction, dockDisplayID, widgets, widgetShortcuts, dockVisible, smoothDockMotion, theme, accent, glassBackground }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = PerchTheme(rawValue: try c.decodeIfPresent(String.self, forKey: .theme) ?? "") ?? .dark
        accent = PerchAccent(rawValue: try c.decodeIfPresent(String.self, forKey: .accent) ?? "") ?? .blue
        glassBackground = try c.decodeIfPresent(Bool.self, forKey: .glassBackground) ?? true
        interactionSounds = try c.decodeIfPresent(Bool.self, forKey: .interactionSounds) ?? true
        alertSounds = try c.decodeIfPresent(Bool.self, forKey: .alertSounds) ?? true
        interactionVolume = max(0, min(1, try c.decodeIfPresent(Double.self, forKey: .interactionVolume) ?? 0.35))
        alertVolume = max(0, min(1, try c.decodeIfPresent(Double.self, forKey: .alertVolume) ?? 0.7))
        focusMinutes = max(1, min(180, try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25))
        reminderListID = try c.decodeIfPresent(String.self, forKey: .reminderListID)
        dockVisible = try c.decodeIfPresent(Bool.self, forKey: .dockVisible) ?? true
        smoothDockMotion = try c.decodeIfPresent(Bool.self, forKey: .smoothDockMotion) ?? true
        dockEdge = try c.decodeIfPresent(DockEdge.self, forKey: .dockEdge) ?? .left
        dockFraction = max(0, min(1, try c.decodeIfPresent(Double.self, forKey: .dockFraction) ?? 0.35))
        dockDisplayID = try c.decodeIfPresent(UInt32.self, forKey: .dockDisplayID)
        widgetShortcuts = try c.decodeIfPresent([String: WidgetShortcut].self, forKey: .widgetShortcuts) ?? [:]
        let rawWidgets = try c.decodeIfPresent([String].self, forKey: .widgets)
        var seen = Set<DockWidget>()
        widgets = rawWidgets.map { $0.compactMap(DockWidget.init(rawValue:)).filter { seen.insert($0).inserted } } ?? DockWidget.defaults
    }
}

public struct AppData: Codable, Equatable, Sendable {
    public var version = 3
    public var utilities: UtilityData? = UtilityData()
    public var play: PlayData? = PlayData()
    public var notes: [Note] = []
    public var noteDraftTitle: String?
    public var noteDraftDetail: String?
    public var snippets: [Snippet] = []
    public var links: [ProjectLink] = []
    public var tray: [TrayItem] = []
    public var priorityIDs: [String] = []
    public var priorityDay = ""
    public var focus: FocusSession?
    public var preferences = Preferences()
    public init() {}
    public mutating func normalizePriorities(now: Date = Date(), calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let key = "\(parts.year!)-\(parts.month!)-\(parts.day!)"
        if key != priorityDay { priorityIDs = []; priorityDay = key }
        var seen = Set<String>()
        priorityIDs = Array(priorityIDs.filter { seen.insert($0).inserted }.prefix(3))
    }
}

public enum PersistenceError: LocalizedError {
    case unsupportedVersion(Int)
    public var errorDescription: String? {
        switch self { case .unsupportedVersion(let version): return "This data was saved by a newer version of Perch (format \(version)). Update Perch before opening it." }
    }
}

public enum Persistence {
    public static func defaultDataURL(demo: Bool = false) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(demo ? "PerchPreview" : "Perch").appendingPathComponent("data.json")
    }
    public static func load(from url: URL) throws -> AppData {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppData() }
        let source = try Data(contentsOf: url)
        struct Envelope: Decodable { var version: Int }
        let format = try JSONDecoder().decode(Envelope.self, from: source).version
        guard (1...3).contains(format) else { throw PersistenceError.unsupportedVersion(format) }
        var data = try JSONDecoder().decode(AppData.self, from: source)
        if format < 3 {
            // Older apps must reject format 3, otherwise their next save could
            // silently drop all new widget data. Preserve the exact old file.
            let backups = url.deletingLastPathComponent().appendingPathComponent("Migration Backups")
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
            try source.write(to: backups.appendingPathComponent("format-\(format)-before-3-\(UUID().uuidString).json"), options: .withoutOverwriting)
            data.version = 3
            // Only the untouched legacy default is updated. Custom orders stay.
            if data.preferences.widgets == [.focus, .today, .notes, .tray, .snippets, .projects] { data.preferences.widgets = DockWidget.defaults }
        }
        if data.utilities == nil { data.utilities = UtilityData() }
        if data.play == nil { data.play = PlayData() }
        return data
    }
    public static func save(_ data: AppData, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: url, options: .atomic)
    }
}
