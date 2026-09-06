import AppKit
import EventKit
import SwiftUI

struct ReminderItem: Identifiable {
    var id: String
    var title: String
    var due: Date?
    var alarm: Date?
    var completed: Bool
    var list: String
    var repeating: Bool
}

enum RepeatChoice: String, CaseIterable, Identifiable {
    case unchanged = "Keep existing", never = "Never", daily = "Daily", weekdays = "Weekdays", weekly = "Weekly", monthly = "Monthly"
    var id: String { rawValue }
    var rule: EKRecurrenceRule? {
        switch self {
        case .unchanged, .never: return nil
        case .daily: return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly: return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .monthly: return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .weekdays:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1,
                daysOfTheWeek: [.init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday), .init(.friday)],
                daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
        }
    }
}

struct TaskDraft: Identifiable {
    var id = UUID()
    var reminderID: String?
    var title = ""
    var hasDue = false
    var due = Date().addingTimeInterval(3600)
    var hasAlarm = false
    var alarm = Date().addingTimeInterval(1200)
    var repetition: RepeatChoice = .never
    init(title: String = "") { self.title = title }
    init(item: ReminderItem) {
        reminderID = item.id; title = item.title
        hasDue = item.due != nil; due = item.due ?? Date().addingTimeInterval(3600)
        hasAlarm = item.alarm != nil; alarm = item.alarm ?? Date().addingTimeInterval(1200)
        repetition = .unchanged
    }
}

@MainActor final class ReminderStore: ObservableObject {
    @Published var items: [ReminderItem] = []
    @Published var calendars: [EKCalendar] = []
    @Published var authorized = false
    @Published var loading = false
    @Published var error: String?
    private let eventStore = EKEventStore()
    private var observer: NSObjectProtocol?
    private var fetchGeneration = 0
    var selectedCalendarID: String?
    let demo: Bool

    init(demo: Bool) {
        self.demo = demo
        if demo {
            authorized = true
            items = [
                .init(id: "demo-1", title: "Give the upload flow a final pass", due: Date().addingTimeInterval(3600), alarm: nil, completed: false, list: "Work", repeating: false),
                .init(id: "demo-2", title: "Write down the next release priorities", due: nil, alarm: nil, completed: false, list: "Work", repeating: false),
                .init(id: "demo-3", title: "Review the new onboarding screens", due: Date().addingTimeInterval(7200), alarm: nil, completed: false, list: "Work", repeating: false)
            ]
        } else {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    func connect() async {
        guard !demo else { return }
        do {
            authorized = try await eventStore.requestFullAccessToReminders()
            if !authorized { error = "Reminders access is off. Enable Perch in System Settings → Privacy & Security → Reminders, then reconnect." }
            refresh()
        } catch { self.error = "Couldn’t connect to Reminders: \(error.localizedDescription)" }
    }

    func refresh() {
        guard !demo else { return }
        let status = EKEventStore.authorizationStatus(for: .reminder)
        authorized = status == .fullAccess
        fetchGeneration += 1
        guard authorized else { items = []; calendars = []; loading = false; return }
        calendars = eventStore.calendars(for: .reminder).filter { $0.allowsContentModifications }
        // An explicit selection scopes both reads and writes. Never silently switch a deleted list.
        guard let selectedCalendarID, let calendar = calendars.first(where: { $0.calendarIdentifier == selectedCalendarID }) else {
            items = []; loading = false; return
        }
        loading = true
        let generation = fetchGeneration
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [calendar])
        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            Task { @MainActor in
                guard let self, generation == self.fetchGeneration else { return }
                self.loading = false
                guard let reminders else { self.error = "Reminders didn’t return this list. Try refreshing."; return }
                self.items = reminders.map { reminder in
                    let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                    let alarm = reminder.alarms?.compactMap { $0.absoluteDate ?? due?.addingTimeInterval($0.relativeOffset) }.min()
                    return ReminderItem(id: reminder.calendarItemIdentifier, title: reminder.title ?? "Untitled task", due: due, alarm: alarm,
                        completed: reminder.isCompleted, list: reminder.calendar.title, repeating: reminder.hasRecurrenceRules)
                }.sorted { ($0.due ?? .distantFuture, $0.title) < ($1.due ?? .distantFuture, $1.title) }
            }
        }
    }

    var selectedListExists: Bool { demo || calendars.contains { $0.calendarIdentifier == selectedCalendarID } }

    func save(_ draft: TaskDraft) throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw message("Give this task a name.") }
        guard !draft.hasAlarm || draft.alarm > Date() else { throw message("Choose a reminder time in the future.") }
        guard draft.repetition == .never || draft.repetition == .unchanged || draft.hasDue else { throw message("Add a due date before setting a repeating task.") }
        if demo {
            if let id = draft.reminderID, let i = items.firstIndex(where: { $0.id == id }) {
                items[i].title = title; items[i].due = draft.hasDue ? draft.due : nil; items[i].alarm = draft.hasAlarm ? draft.alarm : nil
            } else { items.append(.init(id: UUID().uuidString, title: title, due: draft.hasDue ? draft.due : nil, alarm: draft.hasAlarm ? draft.alarm : nil, completed: false, list: "Preview", repeating: false)) }
            return
        }
        guard authorized else { throw message("Connect Apple Reminders first.") }
        guard let calendar = calendars.first(where: { $0.calendarIdentifier == selectedCalendarID }) else { throw message("Choose a Reminders list in Settings first.") }
        let reminder: EKReminder
        if let id = draft.reminderID {
            guard let existing = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { throw message("This task was removed from Reminders. Refresh the list.") }
            guard existing.calendar.calendarIdentifier == selectedCalendarID else { throw message("This task moved to another list. Refresh before editing it.") }
            reminder = existing
        } else { reminder = EKReminder(eventStore: eventStore); reminder.calendar = calendar }
        reminder.title = title
        let originalDue = items.first(where: { $0.id == draft.reminderID })?.due
        let dueChanged = draft.reminderID == nil || draft.hasDue != (originalDue != nil) || (draft.hasDue && originalDue != draft.due)
        if dueChanged {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: draft.due)
            components.calendar = calendar
            reminder.dueDateComponents = draft.hasDue ? components : nil
            if draft.hasDue && (draft.repetition.rule != nil || reminder.hasRecurrenceRules) { reminder.startDateComponents = components }
            if !draft.hasDue && reminder.hasRecurrenceRules && draft.repetition == .unchanged {
                throw message("A repeating task needs its due date. Set Repeat to Never before removing the date.")
            }
        }
        // Preserve unrelated alarms when editing an existing task without changing its reminder time.
        let originalAlarm = items.first(where: { $0.id == draft.reminderID })?.alarm
        let alarmChanged = draft.reminderID == nil || draft.hasAlarm != (originalAlarm != nil) || (draft.hasAlarm && originalAlarm != draft.alarm)
        if alarmChanged {
            reminder.alarms = draft.hasAlarm ? [EKAlarm(absoluteDate: draft.alarm)] : []
        }
        if draft.repetition != .unchanged { reminder.recurrenceRules = draft.repetition.rule.map { [$0] } ?? [] }
        try eventStore.save(reminder, commit: true)
        refresh()
    }

    func complete(_ id: String, completed: Bool = true) throws {
        if demo { items.removeAll { $0.id == id }; return }
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { throw message("This task is no longer available. Refresh the list.") }
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess, reminder.calendar.calendarIdentifier == selectedCalendarID else { throw message("This task is no longer in your selected list. Refresh before changing it.") }
        reminder.isCompleted = completed
        try eventStore.save(reminder, commit: true)
        if completed { items.removeAll { $0.id == id } }
        refresh()
    }

    func snooze(_ id: String, minutes: Int) throws {
        if demo { return }
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { throw message("This task is no longer available.") }
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess, reminder.calendar.calendarIdentifier == selectedCalendarID else { throw message("This task is no longer in your selected list. Refresh before changing it.") }
        reminder.alarms = [EKAlarm(absoluteDate: Date().addingTimeInterval(Double(minutes * 60)))]
        try eventStore.save(reminder, commit: true); refresh()
    }
    private func message(_ text: String) -> NSError { NSError(domain: "Perch", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
}
