import AppKit
import SwiftUI
import PerchCore

enum Section: String, CaseIterable, Identifiable {
    case focus = "Focus", today = "Today", notes = "Notes", tray = "Tray", snippets = "Snippets", projects = "Projects", settings = "Settings", widgets = "Widgets"
    case clipboard = "Clipboard", calculator = "Calculator", converter = "Converter", clocks = "World clock", countdowns = "Countdowns", habits = "Habits", breathing = "Breathing", awake = "Keep awake"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .focus: "timer"
        case .today: "checklist"
        case .notes: "square.and.pencil"
        case .tray: "tray"
        case .snippets: "text.quote"
        case .projects: "square.stack.3d.up"
        case .settings: "slider.horizontal.3"
        case .widgets: "square.grid.2x2"
        case .clipboard: "clipboard"
        case .calculator: "plus.forwardslash.minus"
        case .converter: "arrow.left.arrow.right"
        case .clocks: "globe"
        case .countdowns: "calendar.badge.clock"
        case .habits: "checkmark.circle"
        case .breathing: "wind"
        case .awake: "cup.and.saucer"
        }
    }
}

@MainActor final class AppStore: ObservableObject {
    @Published var data: AppData { didSet {
        scheduleSave()
        if oldValue.focus?.isRunning != data.focus?.isRunning {
            now = Date()
            configureTicker()
        }
    } }
    @Published var section: Section = .today
    @Published var expanded = true
    @Published var panelHeight: CGFloat = 680
    @Published var pointerOffset: CGFloat = 66
    @Published var panelWidth: CGFloat = 480
    @Published var dockRect = CGRect(x: 0, y: 0, width: 76, height: 448)
    @Published var contentRect = CGRect(x: 84, y: 0, width: 420, height: 520)
    @Published var windowSize = CGSize(width: 504, height: 520)
    @Published var editingWidgets = false
    @Published var draggedWidget: DockWidget?
    @Published var isDragging = false
    @Published var dockRevealed = false
    @Published var receivingFiles = false
    @Published var recordingShortcut = false
    @Published var shortcutErrors: [String: String] = [:]
    @Published var capturePresented = false
    @Published var now = Date()
    @Published var toast: String?
    @Published var error: String?
    @Published var storageLocked = false
    @Published var selectedNoteID: UUID?
    @Published var undoLabel: String?
    @Published var breathingSession: BreathingSession? { didSet { configureTicker() } }
    @Published var dockLengthLimit: CGFloat = 1000
    @Published var widgetOffsets: [DockWidget: CGFloat] = [:]
    let awake = AwakeController()
    let reminders: ReminderStore
    let sounds = SoundEngine()
    lazy var notifications = FocusNotifications()
    let demo: Bool
    private let systemServicesEnabled: Bool
    let dataURL: URL
    private var saveTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var undoTask: Task<Void, Never>?
    private var undoAction: (() -> Void)?
    var filesDropped: (() -> Void)?
    var canDismissPanel: (() -> Bool)?
    var canHoverSwitch: (() -> Bool)?
    var activatePanel: (() -> Void)?
    var hoverChanged: ((Bool) -> Void)?
    var dockHoverChanged: ((Bool) -> Void)?
    var revealDockCommand: (() -> Void)?
    var hoveredWidget: DockWidget?
    var dragBegan: (() -> Void)?
    var dragEnded: (() -> Void)?
    var openDialogCount = 0
    var dockSize: CGSize {
        let count = data.preferences.widgets.count
        let length = min(dockLengthLimit, CGFloat(54 + count * (data.preferences.dockEdge.isVertical ? 60 : 58)))
        return data.preferences.dockEdge.isVertical ? CGSize(width: 64, height: length) : CGSize(width: length, height: 66)
    }
    var hoveredWidgetOffset: CGFloat {
        if section == .widgets || section == .settings { return (data.preferences.dockEdge.isVertical ? dockSize.height : dockSize.width) - 17 }
        let widget = DockWidget.allCases.first { $0.section == section }
        if let widget, let offset = widgetOffsets[widget] { return offset }
        let index = widget.flatMap { data.preferences.widgets.firstIndex(of: $0) } ?? 0
        return 52 + CGFloat(index) * (data.preferences.dockEdge.isVertical ? 60 : 58)
    }
    var preferredPanelSize: CGSize {
        let height: CGFloat
        switch section {
        case .focus: height = data.focus == nil ? 156 : 104
        case .today: height = reminders.authorized ? 450 : 340
        case .notes: height = selectedNoteID != nil ? 340 : (data.notes.isEmpty ? 132 : 280)
        case .tray: height = 330
        case .snippets, .projects: height = 360
        case .settings: height = 590
        case .widgets: height = 460
        case .clipboard, .countdowns, .habits: height = 350
        case .calculator: height = 410
        case .converter: height = 295
        case .clocks: height = 385
        case .breathing: height = 295
        case .awake: height = 230
        }
        let feedback: CGFloat = undoLabel != nil || toast != nil ? 52 : 0
        let warning: CGFloat = (error != nil || reminders.error != nil ? 84 : 0) + (storageLocked ? 46 : 0)
        return CGSize(width: section == .widgets ? 400 : (section == .settings ? 380 : 320), height: height + feedback + warning)
    }
    func toggleWidget(_ widget: DockWidget) {
        if let originalIndex = data.preferences.widgets.firstIndex(of: widget) {
            data.preferences.widgets.removeAll { $0 == widget }
            offerUndo("\(widget.title) removed · data kept") { [weak self] in
                guard let self, !self.data.preferences.widgets.contains(widget) else { return }
                self.data.preferences.widgets.insert(widget, at: min(originalIndex, self.data.preferences.widgets.count))
            }
        } else { data.preferences.widgets.append(widget); sounds.play(.drop, preferences: data.preferences) }
    }
    func activateWidgetShortcut(_ widget: DockWidget) { togglePanel(widget.section) }
    func togglePanel(_ target: Section) {
        if expanded && section == target && !capturePresented && canDismissPanel?() != false {
            expanded = false; editingWidgets = false
        } else {
            section = target; editingWidgets = target == .widgets; expanded = true; activatePanel?()
        }
    }
    func setShortcut(_ shortcut: WidgetShortcut?, for widget: DockWidget) {
        if let shortcut {
            let capture = WidgetShortcut(keyCode: 49, modifiers: 6144, display: "⌃⌥Space")
            if shortcut.matches(capture) { error = "Control–Option–Space is used by Quick capture. Choose another shortcut."; return }
            if let duplicate = data.preferences.widgetShortcuts.first(where: { $0.key != widget.rawValue && $0.value.matches(shortcut) }) {
                let title = DockWidget(rawValue: duplicate.key)?.title ?? "another widget"
                error = "That shortcut already opens \(title). Choose a different combination."; return
            }
        }
        data.preferences.widgetShortcuts[widget.rawValue] = shortcut
    }
    private var ticker: Timer?
    private var lastPriorityCheck = Date.distantPast
    var clockInterval: TimeInterval { data.focus?.isRunning == true || breathingSession != nil ? 1 : 60 }

    init(demo: Bool = false, dataURLOverride: URL? = nil, connectSystemServices: Bool = true) {
        self.demo = demo
        systemServicesEnabled = !demo && connectSystemServices
        dataURL = dataURLOverride ?? Persistence.defaultDataURL(demo: demo)
        reminders = ReminderStore(demo: demo || !connectSystemServices)
        var loaded = AppData()
        var loadError: String?
        if !demo {
            do { loaded = try Persistence.load(from: dataURL) }
            catch { loadError = "Your saved data couldn’t be opened. It has been left untouched. \(error.localizedDescription)" }
        }
        loaded.normalizePriorities()
        if demo {
            loaded.priorityIDs = ["demo-1", "demo-2"]
            loaded.notes = [Note(text: "A little room to think\n\nThe best tools disappear until you need them.\n\nNext: try the file tray with a screenshot.")]
            loaded.snippets = [.init(title: "A quick thank you", text: "Thanks for the heads-up! I’ll take a look and get back to you."), .init(title: "Start a local server", text: "python3 -m http.server 8000")]
            loaded.links = [.init(title: "Apple Developer", destination: "https://developer.apple.com", project: "Resources")]
            loaded.focus = FocusSession(title: "Give the upload flow a final pass", reminderID: "demo-1", minutes: 25)
            loaded.preferences.interactionSounds = false
        }
        data = loaded; error = loadError; storageLocked = loadError != nil
        reminders.selectedCalendarID = data.preferences.reminderListID
        if systemServicesEnabled { notifications.errorHandler = { [weak self] message in self?.error = message } }
        lastPriorityCheck = now
        configureTicker()
        if systemServicesEnabled { reminders.refresh(); notifications.update(data.focus, sound: data.preferences.alertSounds) }
    }

    deinit { ticker?.invalidate(); saveTask?.cancel(); toastTask?.cancel(); undoTask?.cancel() }

    private func configureTicker() {
        ticker?.invalidate()
        let interval = clockInterval
        let firstFire = interval == 1 ? Date().addingTimeInterval(1) : Date(timeIntervalSince1970: (floor(Date().timeIntervalSince1970 / 60) + 1) * 60)
        let timer = Timer(fire: firstFire, interval: interval, repeats: true) { [weak self] timer in
            guard self != nil else { timer.invalidate(); return }
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = interval == 1 ? 0.1 : 3
        ticker = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func scheduleSave() {
        guard !demo, !storageLocked else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            self?.flush()
        }
    }
    @discardableResult func flush() -> Bool {
        guard !demo, !storageLocked else { return true }
        do { try Persistence.save(data, to: dataURL); return true }
        catch {
            self.error = "Couldn’t save your changes: \(error.localizedDescription). Keep Perch open and free up space or check folder access."
            return false
        }
    }
    func tick(at date: Date = Date()) {
        now = date
        awake.expire(at: date)
        if let session = breathingSession, session.remaining(at: date) == 0 {
            breathingSession = nil
            if section == .breathing { showToast("Breathing session complete") }
        }
        if !Calendar.current.isDate(lastPriorityCheck, inSameDayAs: date) {
            var normalized = data
            normalized.normalizePriorities(now: date)
            if normalized.priorityDay != data.priorityDay { data = normalized }
            lastPriorityCheck = date
        }
        if let focus = data.focus, focus.isRunning, focus.remaining(at: now) <= 0 {
            data.focus = nil
            if !demo { sounds.play(.finish, preferences: data.preferences) }
            showToast("Focus complete · \(focus.title)")
        }
    }
    func showToast(_ message: String) {
        toastTask?.cancel(); toast = message
        toastTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            self?.toast = nil
        }
    }
    func offerUndo(_ label: String, action: @escaping () -> Void) {
        undoTask?.cancel(); undoLabel = label; undoAction = action
        undoTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            self?.undoLabel = nil; self?.undoAction = nil
        }
    }
    func undo() { undoTask?.cancel(); let action = undoAction; undoLabel = nil; undoAction = nil; action?() }
    func togglePriority(_ id: String) {
        data.normalizePriorities()
        let liveIDs = Set(reminders.items.map(\.id))
        data.priorityIDs.removeAll { !liveIDs.contains($0) }
        if data.priorityIDs.contains(id) { data.priorityIDs.removeAll { $0 == id } }
        else if data.priorityIDs.count < 3 { data.priorityIDs.append(id) }
        else { showToast("Your top three are full. Unpin one to make room.") }
    }
    func complete(_ item: ReminderItem) {
        do {
            try reminders.complete(item.id)
            let wasPinned = data.priorityIDs.contains(item.id)
            data.priorityIDs.removeAll { $0 == item.id }
            sounds.play(.complete, preferences: data.preferences)
            if !item.repeating && !demo {
                offerUndo("Completed “\(item.title)”") { [weak self] in
                    do {
                        try self?.reminders.complete(item.id, completed: false)
                        if wasPinned, let self, self.data.priorityIDs.count < 3 { self.data.priorityIDs.append(item.id) }
                    }
                    catch { self?.error = error.localizedDescription }
                }
            } else { showToast("Task completed") }
        } catch { self.error = error.localizedDescription }
    }
    func startFocus(title: String, reminderID: String? = nil) {
        guard data.focus == nil else { showToast("Finish or stop your current focus session first."); return }
        data.focus = FocusSession(title: title, reminderID: reminderID, minutes: data.preferences.focusMinutes)
        section = .focus
        sounds.play(.start, preferences: data.preferences)
        if systemServicesEnabled { notifications.update(data.focus, sound: data.preferences.alertSounds) }
    }
    func toggleFocus() {
        guard var focus = data.focus else { return }
        if focus.isRunning { focus.pause(); sounds.play(.pause, preferences: data.preferences) }
        else { focus.resume(); sounds.play(.start, preferences: data.preferences) }
        data.focus = focus
        if systemServicesEnabled { notifications.update(focus, sound: data.preferences.alertSounds) }
    }
    func stopFocus() { data.focus = nil; if systemServicesEnabled { notifications.update(nil, sound: false) } }
    func selectList(_ id: String) {
        if id != data.preferences.reminderListID { data.priorityIDs = [] }
        data.preferences.reminderListID = id.isEmpty ? nil : id
        reminders.selectedCalendarID = data.preferences.reminderListID
        reminders.refresh()
    }
    func addNote(_ text: String = "") {
        let note = Note(text: text); data.notes.insert(note, at: 0)
        selectedNoteID = note.id; section = .notes
    }
    func updateNote(_ id: UUID, text: String) {
        guard let index = data.notes.firstIndex(where: { $0.id == id }) else { return }
        data.notes[index].text = text; data.notes[index].updatedAt = Date()
    }
    func deleteNote(_ note: Note) {
        data.notes.removeAll { $0.id == note.id }; selectedNoteID = nil
        offerUndo("Note deleted") { [weak self] in self?.data.notes.insert(note, at: 0) }
    }
    func copy(_ snippet: Snippet) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.text, forType: .string)
        sounds.play(.copy, preferences: data.preferences); showToast("Copied \(snippet.title)")
    }
    func removeSnippet(_ snippet: Snippet) {
        data.snippets.removeAll { $0.id == snippet.id }
        offerUndo("Snippet deleted") { [weak self] in self?.data.snippets.append(snippet) }
    }
    func addFiles(_ urls: [URL]) {
        var added = 0
        for url in urls where url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path), !data.tray.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { continue }
            let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            data.tray.append(TrayItem(url: url, bookmark: bookmark)); added += 1
        }
        if added > 0 { sounds.play(.drop, preferences: data.preferences); showToast("\(added) \(added == 1 ? "file" : "files") added to the tray") }
        if added == 0 && !urls.isEmpty { showToast("These files are already in the tray or are no longer available.") }
        section = .tray
    }
    func resolve(_ item: TrayItem) -> URL {
        if let bookmark = item.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale) { return url }
        }
        return item.url
    }
    func removeTray(_ item: TrayItem) {
        data.tray.removeAll { $0.id == item.id }
        offerUndo("Removed from tray · original kept") { [weak self] in self?.data.tray.append(item) }
    }
    func chooseFiles() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = true
        panel.prompt = "Add to tray"
        openDialogCount += 1
        panel.begin { [weak self] response in
            Task { @MainActor in
                self?.openDialogCount -= 1
                if response == .OK { self?.addFiles(panel.urls) }
            }
        }
    }
    func open(_ link: ProjectLink) {
        var url = link.safeURL
        if let bookmark = link.bookmark {
            var stale = false
            url = (try? URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)) ?? url
        }
        guard let url else { error = "This shortcut needs a valid website, app, or folder."; return }
        if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) { error = "“\(link.title)” has moved or is unavailable. Edit the shortcut to select it again."; return }
        NSWorkspace.shared.open(url, configuration: .init()) { [weak self] _, error in
            if let error { Task { @MainActor in self?.error = "Couldn’t open \(link.title): \(error.localizedDescription)" } }
        }
    }
}
