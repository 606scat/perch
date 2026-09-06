import SwiftUI
import AppKit
import PerchCore
import ServiceManagement

struct TaskComposer: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminders: ReminderStore
    @Environment(\.dismiss) var dismiss
    @State var draft: TaskDraft
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.reminderID == nil ? "A task to come back to" : "Edit task").font(.title2.bold())
            TaskFields(draft: $draft)
            if let error { Text(error).font(.caption).foregroundStyle(Palette.warning) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save task") {
                    do { try reminders.save(draft); store.showToast("Saved to Reminders"); dismiss() }
                    catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent).keyboardShortcut(.defaultAction)
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 410)
            .tint(store.accentColor).accentColor(store.accentColor)
    }
}

struct TaskFields: View {
    @Binding var draft: TaskDraft
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("What do you need to do?", text: $draft.title, axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder)
            Toggle("Due date", isOn: $draft.hasDue)
            if draft.hasDue { DatePicker("Due", selection: $draft.due, displayedComponents: [.date, .hourAndMinute]) }
            Toggle("Remind me", isOn: $draft.hasAlarm)
            if draft.hasAlarm {
                DatePicker("Reminder", selection: $draft.alarm, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                HStack {
                    ForEach([20, 60], id: \.self) { minutes in
                        Button("In \(minutes) min") { draft.alarm = Date().addingTimeInterval(Double(minutes * 60)) }.font(.caption)
                    }
                }
            }
            Picker("Repeat", selection: $draft.repetition) {
                ForEach(RepeatChoice.allCases.filter { draft.reminderID != nil || $0 != .unchanged }) { Text($0.rawValue).tag($0) }
            }
            Text("Tasks are saved in your selected Apple Reminders list. Reminder delivery follows your macOS notification settings.")
                .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CaptureView: View {
    enum Kind: String, CaseIterable { case note = "Note", task = "Task", snippet = "Snippet" }
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminders: ReminderStore
    @Environment(\.dismiss) var dismiss
    @State private var kind: Kind = .note
    @State private var text = ""
    @State private var name = ""
    @State private var draft = TaskDraft()
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Get it out of your head.").font(.system(size: 23, weight: .semibold, design: .rounded))
            Picker("Capture type", selection: $kind) { ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            if kind == .task {
                if reminders.authorized && reminders.selectedListExists { TaskFields(draft: $draft) }
                else {
                    Text("Connect Apple Reminders and choose a list in Settings to capture tasks.").foregroundStyle(Palette.secondary)
                    Button("Open Settings") { store.section = .settings; dismiss() }
                }
            } else {
                if kind == .snippet { TextField("Snippet name", text: $name).textFieldStyle(.roundedBorder) }
                TextEditor(text: $text).font(.system(size: 14)).frame(height: 170).accessibilityLabel(kind == .note ? "Quick note" : "Snippet text")
                Text(kind == .note ? "Saved privately on this Mac." : "Click it later to copy instantly.").font(.caption).foregroundStyle(Palette.secondary)
            }
            if let error { Text(error).font(.caption).foregroundStyle(Palette.warning) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save \(kind.rawValue.lowercased())") { save() }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent).keyboardShortcut(.defaultAction).disabled(!canSave)
            }
        }.padding(24).frame(width: 410)
            .tint(store.accentColor).accentColor(store.accentColor)
    }
    var canSave: Bool {
        switch kind {
        case .task: reminders.authorized && reminders.selectedListExists && !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .note: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .snippet: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    func save() {
        switch kind {
        case .note: store.addNote(text); store.showToast("Note saved")
        case .snippet:
            store.data.snippets.insert(Snippet(title: name.trimmingCharacters(in: .whitespacesAndNewlines), text: text), at: 0)
            store.section = .snippets; store.showToast("Snippet pinned")
        case .task:
            do { try reminders.save(draft); store.section = .today; store.showToast("Saved to Reminders") }
            catch { self.error = error.localizedDescription; return }
        }
        dismiss()
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminders: ReminderStore
    @State private var notificationMessage: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings").font(.system(size: 16, weight: .semibold)).padding(.top, 16)
                AppearanceSettings()
                if let updates = store.updates { Divider(); UpdateSettings(updates: updates) }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple Reminders").font(.headline)
                    if reminders.authorized {
                        Picker("Task list", selection: Binding(get: { store.data.preferences.reminderListID ?? "" }, set: { store.selectList($0) })) {
                            Text("Choose a list…").tag("")
                            ForEach(reminders.calendars, id: \.calendarIdentifier) { calendar in Text(calendar.title).tag(calendar.calendarIdentifier) }
                        }.disabled(store.demo)
                        Text("Only the selected list appears in Perch. Choose a personal list to keep your tasks private.").font(.caption).foregroundStyle(Palette.secondary)
                        Button("Refresh lists") { reminders.refresh() }.font(.caption)
                    } else {
                        Button("Connect Apple Reminders") { Task { await reminders.connect() } }.buttonStyle(BlueActionStyle())
                        Text("Apple will ask you to allow Reminders access.").font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus").font(.headline)
                    Picker("Session length", selection: $store.data.preferences.focusMinutes) {
                        ForEach([15, 25, 45, 60, 90], id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    Button("Enable focus notifications") {
                        Task {
                            guard !store.demo else { notificationMessage = "Notifications are disabled in preview mode."; return }
                            let allowed = await store.notifications.requestAccess()
                            notificationMessage = allowed ? "Focus notifications are enabled." : "Allow Perch in System Settings → Notifications to receive focus alerts."
                            store.notifications.update(store.data.focus, sound: store.data.preferences.alertSounds)
                        }
                    }.buttonStyle(.bordered)
                    Text(notificationMessage ?? "Enable notifications for timer completion while Perch is in the background. Focus modes and system settings still apply.")
                        .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sound & feel").font(.headline)
                    Toggle("Interaction sounds", isOn: $store.data.preferences.interactionSounds)
                    HStack {
                        Slider(value: $store.data.preferences.interactionVolume, in: 0...1).accessibilityLabel("Interaction volume")
                        Button("Preview completion") { store.sounds.play(.complete, preferences: store.data.preferences, preview: true) }
                    }.disabled(!store.data.preferences.interactionSounds)
                    Toggle("Focus alert sounds", isOn: $store.data.preferences.alertSounds)
                        .onChange(of: store.data.preferences.alertSounds) { _, value in if !store.demo { store.notifications.update(store.data.focus, sound: value) } }
                    HStack {
                        Slider(value: $store.data.preferences.alertVolume, in: 0...1).accessibilityLabel("In-app focus alert volume")
                        Button("Preview") { store.sounds.play(.finish, preferences: store.data.preferences, preview: true) }
                    }.disabled(!store.data.preferences.alertSounds)
                    Text("These sliders control sounds inside Perch. Background notification volume and Apple Reminders alerts use your system settings.")
                        .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        ForEach([SoundEngine.Cue.copy, .drop, .start, .pause], id: \.rawValue) { cue in
                            Button(cue.rawValue.capitalized) { store.sounds.play(cue, preferences: store.data.preferences, preview: true) }.font(.caption)
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("At your fingertips").font(.headline)
                    Toggle("Show dock on screen", isOn: $store.data.preferences.dockVisible)
                    Toggle("Smooth dock motion", isOn: $store.data.preferences.smoothDockMotion)
                    Text("Animate the dock sliding in and out, even when macOS Reduce Motion is on.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                    Text("The Perch menu bar stays available when the dock is hidden.").font(.caption).foregroundStyle(Palette.secondary)
                    Button("Edit widgets & shortcuts…") { store.section = .widgets; store.editingWidgets = true }
                    Picker("Dock edge", selection: $store.data.preferences.dockEdge) {
                        ForEach(DockEdge.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Text("Drag the grip to any screen edge. Hover to expand; move away to tuck it back. Editing keeps the panel open.")
                        .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack { Text("Quick capture"); Spacer(); Text("Control–Option–Space").foregroundStyle(Palette.secondary) }
                    Toggle("Open at login", isOn: $launchAtLogin).disabled(store.demo).onChange(of: launchAtLogin) { _, value in
                        guard !store.demo else { return }
                        do {
                            if value { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch { store.error = "Couldn’t change login startup: \(error.localizedDescription)"; launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
                    Text("Perch \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development") · build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")\nYour notes, snippets, and shortcuts stay on this Mac.").font(.caption).foregroundStyle(Palette.secondary)
                    Button("Show local data folder") { NSWorkspace.shared.open(store.dataURL.deletingLastPathComponent()) }.font(.caption)
                }
            }.padding(.horizontal, 22).padding(.bottom, 24)
        }
    }
}
