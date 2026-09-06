import AppKit
import SwiftUI
import PerchCore

struct PanelView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminders: ReminderStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var taskDraft: TaskDraft?
    @State private var dropTarget = false
    @State private var stopConfirmation = false

    var body: some View {
        expandedPanel.padding(8).background {
            PerchSurface().clipShape(FlyoutShape(edge: store.data.preferences.dockEdge, pointerOffset: store.pointerOffset))
                .overlay(FlyoutShape(edge: store.data.preferences.dockEdge, pointerOffset: store.pointerOffset).stroke(Palette.rule.opacity(0.18), lineWidth: 0.7))
        }
        .clipShape(FlyoutShape(edge: store.data.preferences.dockEdge, pointerOffset: store.pointerOffset))

        .accentColor(store.accentColor)
        .tint(store.accentColor)
        .font(.system(size: 13))
        .foregroundStyle(Palette.primary)
        .onHover { store.hoverChanged?($0) }
        .onExitCommand { store.expanded = false; store.editingWidgets = false }
        .sheet(item: $taskDraft) { TaskComposer(draft: $0).environmentObject(store).environmentObject(reminders) }
        .sheet(isPresented: $store.capturePresented) { CaptureView().environmentObject(store).environmentObject(reminders) }
        .alert("Stop this focus session?", isPresented: $stopConfirmation) {
            Button("Keep focusing", role: .cancel) {}
            Button("Stop session", role: .destructive) { store.stopFocus() }
        } message: { Text("Your task stays in Reminders. Only this timer will stop.") }

    }

    private var expandedPanel: some View {
        VStack(spacing: 0) {
            if store.storageLocked {
                Label("Saved data is protected. Restart after resolving the storage error.", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(Palette.warning).padding(.horizontal, 22)
            }
            if let error = store.error ?? reminders.error {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    ScrollView { Text(error).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 60)
                    Spacer(minLength: 0)
                    if !store.storageLocked { Button { store.error = nil; reminders.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Dismiss error") }
                }.foregroundStyle(Palette.error).padding(12).background(.red.opacity(0.09))
            }

            Group {
                switch store.section {
                case .focus: FocusDetailView()
                case .today: today
                case .notes: NotesView()
                case .tray: TrayView()
                case .snippets: SnippetsView()
                case .projects: ProjectsView()
                case .settings: SettingsView()
                case .widgets: WidgetGallery()
                case .clipboard: ClipboardWidgetView()
                case .calculator: CalculatorWidgetView()
                case .converter: ConverterWidgetView()
                case .clocks: ClocksWidgetView()
                case .countdowns: CountdownsWidgetView()
                case .habits: HabitsWidgetView()
                case .breathing: BreathingWidgetView()
                case .awake: AwakeWidgetView(controller: store.awake)
                case .colors: ColorsWidgetView()
                case .qr: QRWidgetView()
                case .textTools: TextToolsWidgetView()
                case .decisions: DecisionsWidgetView()
                case .doodle: DoodleWidgetView()
                case .garden: GardenWidgetView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .disabled(store.storageLocked)

            if let undo = store.undoLabel {
                HStack(spacing: 8) {
                    Text(undo).font(.system(size: 11)).lineLimit(2).foregroundStyle(Palette.secondary)
                    Spacer(minLength: 0)
                    Button("Undo") { store.undo() }.buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(store.accentColor).padding(.vertical, 8).padding(.horizontal, 4)
                }
                .padding(.horizontal, 12).frame(height: 40)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 8).padding(.bottom, 8).padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
            } else if let toast = store.toast {
                HStack(spacing: 8) { Image(systemName: "checkmark").foregroundStyle(store.accentColor); Text(toast).lineLimit(2); Spacer() }
                    .font(.caption).padding(.horizontal, 12).frame(height: 40)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 8).padding(.bottom, 8).padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }.frame(width: max(0, store.panelWidth - 16), height: max(0, store.panelHeight - 16))
    }

    private var today: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Today").font(.system(size: 14, weight: .semibold))
                        Text(store.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    if reminders.authorized && reminders.selectedListExists {
                        Button { taskDraft = TaskDraft() } label: { Label("New task", systemImage: "plus") }.buttonStyle(.bordered)
                    }
                }
                if !reminders.authorized { connectCard }
                else if !reminders.selectedListExists {
                    EmptyState(symbol: "list.bullet.rectangle", title: "Choose your task list", detail: "Pick a Reminders list in Settings. Perch will only show tasks from that list.")
                    Button("Choose a list") { store.section = .settings }.buttonStyle(BlueActionStyle())
                } else {
                    let priorities = reminders.items.filter { store.data.priorityIDs.contains($0.id) }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your top three").font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text("\(priorities.count) / 3").font(.caption).foregroundStyle(Palette.secondary)
                        }
                        if priorities.isEmpty {
                            Text("Pin up to three tasks worth making room for today.").foregroundStyle(Palette.secondary).font(.system(size: 13)).padding(.vertical, 12)
                        } else {
                            ForEach(priorities) { item in taskRow(item, priority: true) }
                        }
                    }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Your tasks").font(.system(size: 14, weight: .semibold))
                            Spacer()
                            if reminders.loading { ProgressView().controlSize(.small) }
                            iconButton("Refresh tasks", symbol: "arrow.clockwise") { reminders.refresh() }
                        }
                        let others = reminders.items.filter { !store.data.priorityIDs.contains($0.id) }
                        if others.isEmpty && !reminders.loading {
                            Text(priorities.isEmpty ? "Nothing waiting here. Add your first task." : "Everything else can wait.")
                                .foregroundStyle(Palette.secondary).padding(.vertical, 16)
                        }
                        ForEach(others) { item in taskRow(item, priority: false) }
                    }
                }
                if store.data.focus == nil {
                    Button { store.startFocus(title: "A little uninterrupted time") } label: {
                        HStack { Image(systemName: "timer"); Text("Start a \(store.data.preferences.focusMinutes)-minute focus"); Spacer(); Image(systemName: "arrow.right") }
                            .foregroundStyle(store.accentColor).padding(.vertical, 8)
                    }.buttonStyle(.plain)
                }
            }.padding(14)
        }
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            WidgetGlyph(widget: .today).frame(width: 31, height: 31).foregroundStyle(store.accentColor)
            Text("Your tasks, a little closer.").font(.system(size: 16, weight: .medium))
            Text("Connect Apple Reminders to bring a list here. Your notes, snippets, and file tray are ready now.")
                .foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
            Button("Connect Apple Reminders") { Task { await reminders.connect(); if reminders.authorized { store.section = .settings } } }
                .buttonStyle(BlueActionStyle()).controlSize(.large)
            Text("You choose which list appears. Nothing is shared by Perch.").font(.caption).foregroundStyle(Palette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func taskRow(_ item: ReminderItem, priority: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { store.complete(item) } label: { Image(systemName: "circle").font(.system(size: 20, weight: .light)).foregroundStyle(priority ? store.accentColor : Palette.secondary) }
                .buttonStyle(.plain).help("Complete \(item.title)").accessibilityLabel("Complete \(item.title)")
            Button { taskDraft = TaskDraft(item: item) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(.system(size: 13, weight: .medium)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if let due = item.due {
                            Text(due.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .foregroundStyle(due < store.now ? Palette.warning : Palette.secondary)
                        }
                        if item.alarm != nil { Image(systemName: "bell") }
                        if item.repeating { Image(systemName: "repeat") }
                    }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("Edit task")
            Menu {
                Button(priority ? "Remove from top three" : "Pin to top three", systemImage: priority ? "pin.slash" : "pin") { store.togglePriority(item.id) }
                Button("Focus on this task", systemImage: "timer") { store.startFocus(title: item.title, reminderID: item.id) }.disabled(store.data.focus != nil)
                Button("Remind me in 20 minutes", systemImage: "bell") {
                    do { try reminders.snooze(item.id, minutes: 20); store.showToast("Reminder set for 20 minutes from now") }
                    catch { store.error = error.localizedDescription }
                }
                Button("Edit task", systemImage: "pencil") { taskDraft = TaskDraft(item: item) }
            } label: { Image(systemName: "ellipsis").foregroundStyle(Palette.secondary).frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Task actions")
        }.padding(.vertical, 8)
    }


}

func timeString(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(ceil(interval)))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

func iconButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) { Image(systemName: symbol).font(.system(size: 13)).frame(width: 26, height: 26).contentShape(Rectangle()) }
        .buttonStyle(.plain).foregroundStyle(Palette.secondary).help(title).accessibilityLabel(title)
}

struct EmptyState: View {
    @EnvironmentObject var store: AppStore
    var symbol: String
    var title: String
    var detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if symbol == "text.quote" { WidgetGlyph(widget: .snippets).frame(width: 32, height: 32) }
                else if symbol == "square.stack.3d.up" { WidgetGlyph(widget: .projects).frame(width: 32, height: 32) }
                else { Image(systemName: symbol).font(.system(size: 31, weight: .light)) }
            }.foregroundStyle(store.accentColor).padding(.bottom, 5)
            Text(title).font(.system(size: 16, weight: .medium))
            Text(detail).foregroundStyle(Palette.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 22)
    }
}

struct PageHeading: View {
    var title: String
    var detail: String
    var action: String
    var onAdd: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(Palette.secondary)
            }
            Spacer()
            Button(action, systemImage: "plus", action: onAdd).buttonStyle(.bordered)
        }
    }
}

struct BlueActionStyle: ButtonStyle {
    @EnvironmentObject var store: AppStore
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(enabled ? (configuration.isPressed ? Palette.onAccent : store.accentColor) : Palette.secondary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(store.accentColor.opacity(enabled ? (configuration.isPressed ? 1 : 0.10) : 0.04), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.accentColor.opacity(enabled ? 0.25 : 0.08), lineWidth: 0.7))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
