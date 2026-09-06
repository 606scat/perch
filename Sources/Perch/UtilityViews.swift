import AppKit
import SwiftUI
import PerchCore

/// Explicit empty-field text avoids AppKit dimming small native placeholders.
struct PerchEntry: View {
    var title: String
    @Binding var text: String
    init(_ title: String, text: Binding<String>) { self.title = title; _text = text }
    var body: some View {
        TextField("", text: $text).textFieldStyle(.plain)
            .overlay(alignment: .leading) { if text.isEmpty { Text(title).foregroundStyle(Palette.secondary).allowsHitTesting(false).accessibilityHidden(true) } }
            .padding(7).background(Palette.field, in: RoundedRectangle(cornerRadius: 7)).accessibilityLabel(title)
    }
}

struct ClipboardWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var clearing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Clipboard").font(.system(size: 14, weight: .semibold)); Spacer()
                Button("Keep copied text", systemImage: "plus") { store.captureClipboard() }.buttonStyle(.bordered)
            }
            Text("Keep a few things while you work. Only captures when you ask.").font(.caption).foregroundStyle(Palette.secondary)
            if store.utilities.clips.isEmpty {
                Spacer(minLength: 0)
                WidgetGlyph(widget: .clipboard).frame(width: 34, height: 34).foregroundStyle(store.accentColor)
                Text("Copy text in any app, then keep it here.").font(.system(size: 13, weight: .medium))
                Text("Up to 30 items. Saved on this Mac.").font(.caption).foregroundStyle(Palette.secondary)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.utilities.clips) { clip in
                            HStack(alignment: .top, spacing: 8) {
                                Button { store.copyText(clip.text) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(clip.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                        Text("\(clip.text.count) characters · \(clip.capturedAt.formatted(.dateTime.hour().minute()))").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).help("Copy this text")
                                Menu {
                                    Button("Save as snippet") { store.data.snippets.insert(Snippet(title: clip.title, text: clip.text), at: 0); store.showToast("Saved to Snippets") }
                                    Button("Remove") { store.removeClip(clip) }
                                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                            }.padding(.vertical, 10)
                            Divider().overlay(Palette.rule.opacity(0.08))
                        }
                    }
                }
                HStack { Text("Click an item to copy it.").font(.caption).foregroundStyle(Palette.secondary); Spacer(); Button("Clear all") { clearing = true }.buttonStyle(.plain).foregroundStyle(Palette.secondary) }
            }
        }.padding(14)
        .alert("Clear \(store.utilities.clips.count) clipboard items?", isPresented: $clearing) {
            Button("Cancel", role: .cancel) {}
            Button("Clear items", role: .destructive) {
                let old = store.utilities.clips; store.utilities.clips = []
                store.offerUndo("Clipboard shelf cleared") { store.utilities.clips = old + store.utilities.clips.filter { item in !old.contains(where: { $0.id == item.id }) } }
            }
        } message: { Text("Saved snippets and your Mac’s current clipboard are kept. Undo is available for 10 seconds.") }
    }
}

struct CalculatorWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var result: String?
    @FocusState private var editing: Bool
    private let keys = ["C", "(", ")", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "0", ".", "%", "="]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Calculator").font(.system(size: 14, weight: .semibold)); Spacer(); iconButton("Delete last character", symbol: "delete.left") { if !store.utilities.calculatorInput.isEmpty { store.utilities.calculatorInput.removeLast(); result = nil } } }
            PerchEntry("Expression", text: Binding(get: { store.utilities.calculatorInput }, set: { store.utilities.calculatorInput = String($0.prefix(256)); result = nil }))
                .font(.system(size: 17, design: .monospaced)).focused($editing)
                .onSubmit { result = store.calculate() }.accessibilityLabel("Calculation expression")
            HStack {
                Text(result ?? (store.utilities.calculatorInput.isEmpty ? "0" : "Press = or Return"))
                    .font(.system(size: result == nil ? 12 : 23, weight: .medium, design: .monospaced))
                    .foregroundStyle(result == nil ? Palette.secondary : store.accentColor).lineLimit(1).minimumScaleFactor(0.65)
                Spacer(minLength: 0)
                if let result { iconButton("Copy result", symbol: "doc.on.doc") { store.copyText(result) } }
            }.frame(height: 32)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
                ForEach(keys, id: \.self) { key in
                    Button { press(key) } label: {
                        Text(key).font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity).frame(height: 28)
                            .foregroundStyle(key == "=" ? Palette.onAccent : Palette.primary)
                            .background(key == "=" ? store.accentColor : Palette.surface, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain).accessibilityLabel(key == "=" ? "Calculate" : key == "C" ? "Clear calculation" : key)
                }
            }
            Text("% divides by 100 · ^ raises to a power").font(.system(size: 10)).foregroundStyle(Palette.secondary)
            if !store.utilities.calculations.isEmpty {
                Divider()
                Menu {
                    ForEach(store.utilities.calculations) { item in
                        Button("\(item.expression) = \(item.result)") { store.utilities.calculatorInput = item.expression; result = item.result }
                    }
                } label: {
                    Label("History · \(store.utilities.calculations.count)", systemImage: "clock.arrow.circlepath").font(.system(size: 11))
                }.menuStyle(.borderlessButton).fixedSize().help("Reuse a recent calculation")
            }
            Spacer(minLength: 0)
        }.padding(14)
    }
    private func press(_ key: String) {
        if key == "C" { store.utilities.calculatorInput = ""; result = nil }
        else if key == "=" { result = store.calculate() }
        else {
            if result != nil {
                store.utilities.calculatorInput = ["+", "−", "×", "÷", "%"].contains(key) ? result! : ""
                result = nil
            }
            if store.utilities.calculatorInput.count < 256 { store.utilities.calculatorInput += key }
        }
    }
}

struct ConverterWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var category: UnitCategory = .length
    @State private var input = "1"
    @State private var from = "m"
    @State private var to = "ft"
    private var units: [ConversionUnit] { ConversionUnit.all.filter { $0.category == category } }
    private var value: Double? { Double(input.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var convertedValue: Double? { value.flatMap { try? ConversionUnit.convert($0, from: from, to: to) } }
    private var result: String? { convertedValue.map(Calculator.format) }
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text("Unit converter").font(.system(size: 14, weight: .semibold)); Spacer() }
            Picker("Category", selection: $category) { ForEach(UnitCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .onChange(of: category) { _, _ in from = units[0].id; to = units[1].id }
            HStack {
                PerchEntry("Value", text: $input).font(.system(size: 18, design: .monospaced)).accessibilityLabel("Value to convert")
                Picker("From", selection: $from) { ForEach(units) { Text($0.id).tag($0.id) } }.labelsHidden().frame(width: 86).accessibilityLabel("From unit")
            }
            HStack { Rectangle().fill(Palette.rule.opacity(0.1)).frame(height: 1); iconButton("Swap units", symbol: "arrow.up.arrow.down") { let converted = convertedValue; let old = from; from = to; to = old; if let converted { input = String(converted) } }; Rectangle().fill(Palette.rule.opacity(0.1)).frame(height: 1) }
            HStack {
                Text(result ?? "—").font(.system(size: 23, weight: .medium, design: .monospaced)).foregroundStyle(store.accentColor).lineLimit(1).minimumScaleFactor(0.65)
                Spacer(minLength: 0)
                Picker("To", selection: $to) { ForEach(units) { Text($0.id).tag($0.id) } }.labelsHidden().frame(width: 86).accessibilityLabel("To unit")
            }
            HStack {
                Text(result == nil ? "Enter a finite number; use . for decimals." : "\(units.first(where: { $0.id == from })?.name ?? from) → \(units.first(where: { $0.id == to })?.name ?? to)")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Copy") { if let result { store.copyText(result) } }.buttonStyle(.bordered).disabled(result == nil)
            }
            Spacer(minLength: 0)
        }.padding(14)
    }
}

struct ClockReading {
    var time: String
    var day: String
    var offset: String
    init(zone: String, date: Date) {
        let timezone = TimeZone(identifier: zone) ?? .current
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timezone
        let c = calendar.dateComponents([.hour, .minute, .day, .month], from: date)
        time = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        var format = Date.FormatStyle(date: .abbreviated, time: .omitted); format.timeZone = timezone
        day = date.formatted(format)
        let minutes = timezone.secondsFromGMT(for: date) / 60
        offset = String(format: "UTC%@%d:%02d", minutes >= 0 ? "+" : "−", abs(minutes) / 60, abs(minutes) % 60)
    }
}

struct ClocksWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var adding = false
    @State private var shift: Double = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { Text("World clock").font(.system(size: 14, weight: .semibold)); Spacer(); Button("Add city", systemImage: "plus") { adding = true }.buttonStyle(.bordered).disabled(store.utilities.clockZones.count >= 8) }
            ScrollView {
                VStack(spacing: 0) {
                    if store.utilities.clockZones.isEmpty { Text("Add a city to compare times.").foregroundStyle(Palette.secondary).padding(.vertical, 22) }
                    ForEach(store.utilities.clockZones, id: \.self) { zone in
                        let reading = ClockReading(zone: zone, date: store.now.addingTimeInterval(shift * 3600))
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(zone.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? zone).font(.system(size: 12, weight: .medium))
                                Text("\(reading.day) · \(reading.offset)").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                            }
                            Spacer(minLength: 0)
                            Text(reading.time).font(.system(size: 21, weight: .medium, design: .monospaced)).foregroundStyle(store.accentColor)
                            iconButton("Remove \(zone)", symbol: "minus.circle") {
                                let index = store.utilities.clockZones.firstIndex(of: zone) ?? 0
                                store.utilities.clockZones.removeAll { $0 == zone }
                                store.offerUndo("City removed") { if !store.utilities.clockZones.contains(zone) { store.utilities.clockZones.insert(zone, at: min(index, store.utilities.clockZones.count)) } }
                            }
                        }.padding(.vertical, 11)
                        Divider()
                    }
                }
            }
            HStack { Text(shift == 0 ? "Live time" : "Preview \(shift > 0 ? "+" : "")\(Calculator.format(shift)) hours").font(.caption).foregroundStyle(Palette.secondary); Spacer(); if shift != 0 { Button("Now") { shift = 0 }.buttonStyle(.plain).foregroundStyle(store.accentColor) } }
            Slider(value: $shift, in: -12...24, step: 0.5).accessibilityLabel("Preview time in hours from now")
            Text("Slide to find a time that works across cities.").font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }.padding(14)
        .sheet(isPresented: $adding) { CityPicker().environmentObject(store) }
    }
}

private struct CityPicker: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var zones: [String] { WorldCities.matching(query) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Add a city").font(.headline); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            PerchEntry("Search cities", text: $query).accessibilityLabel("Search time zones")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if zones.isEmpty { Text("No cities match. Try another city or region.").font(.caption).foregroundStyle(Palette.secondary).padding(.vertical, 16) }
                    ForEach(zones, id: \.self) { zone in
                        Button {
                            if !store.utilities.clockZones.contains(zone), store.utilities.clockZones.count < 8 { store.utilities.clockZones.append(zone) }; dismiss()
                        } label: { HStack { Text(zone.replacingOccurrences(of: "_", with: " ")); Spacer(); Image(systemName: store.utilities.clockZones.contains(zone) ? "checkmark" : "plus") }.padding(.vertical, 7).contentShape(Rectangle()) }
                            .buttonStyle(.plain).disabled(store.utilities.clockZones.contains(zone)).font(.system(size: 12))
                    }
                }
            }.frame(height: 270)
        }.padding(20).frame(width: 360).tint(store.accentColor).accentColor(store.accentColor)
    }
}

struct CountdownsWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: Milestone?
    @State private var deleting: Milestone?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Countdowns").font(.system(size: 14, weight: .semibold)); Spacer(); Button("New", systemImage: "plus") { editing = Milestone(title: "", date: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()) }.buttonStyle(.bordered) }
            Text("A launch, a trip, or something to look forward to.").font(.caption).foregroundStyle(Palette.secondary)
            if store.utilities.milestones.isEmpty {
                Spacer(); WidgetGlyph(widget: .countdowns).frame(width: 36, height: 36).foregroundStyle(store.accentColor)
                Text("Keep an important date in sight.").font(.system(size: 13, weight: .medium)); Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.utilities.milestones.sorted { $0.date < $1.date }) { item in
                            let days = item.days(from: store.now)
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(days == 0 ? "Today" : "\(abs(days))").font(.system(size: days == 0 ? 18 : 27, weight: .medium, design: .rounded)).foregroundStyle(store.accentColor)
                                    if days != 0 { Text(days < 0 ? "days ago" : "days left").font(.system(size: 9)).foregroundStyle(Palette.secondary) }
                                }.frame(width: 56, alignment: .leading)
                                Button { editing = item } label: {
                                    VStack(alignment: .leading, spacing: 4) { Text(item.title).font(.system(size: 12, weight: .medium)).lineLimit(2); Text(item.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 10)).foregroundStyle(Palette.secondary) }
                                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                iconButton("Delete \(item.title)", symbol: "trash") { deleting = item }
                            }.padding(.vertical, 12)
                            Divider()
                        }
                    }
                }
            }
        }.padding(14)
        .sheet(item: $editing) { MilestoneEditor(item: $0).environmentObject(store) }
        .alert("Delete this countdown?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) { if let deleting { store.removeMilestone(deleting) }; deleting = nil }
        } message: { Text("You can undo this for 10 seconds.") }
    }
}

private struct MilestoneEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var item: Milestone
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("An important date").font(.headline)
            PerchEntry("Name", text: $item.title)
            DatePicker("Date", selection: $item.date, displayedComponents: .date).datePickerStyle(.graphical)
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Save") { store.saveMilestone(item); dismiss() }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent).keyboardShortcut(.defaultAction).disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(20).frame(width: 340).tint(store.accentColor).accentColor(store.accentColor)
    }
}

struct HabitsWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var title = ""
    @State private var deleting: DailyHabit?
    @State private var editing: DailyHabit?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Habits").font(.system(size: 14, weight: .semibold)); Spacer(); Text("\(store.utilities.habits.filter { $0.completed(on: store.now) }.count)/\(store.utilities.habits.count) today").font(.caption).foregroundStyle(Palette.secondary) }
            HStack {
                PerchEntry("A small daily habit", text: $title).onSubmit { add() }
                Button("Add", systemImage: "plus") { add() }.labelStyle(.iconOnly).buttonStyle(.bordered).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if store.utilities.habits.isEmpty { Text("Write a habit, then check in once a day. Your streak can continue from yesterday.").font(.system(size: 12)).foregroundStyle(Palette.secondary).padding(.top, 18) }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.utilities.habits) { habit in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 10) {
                                Button { store.toggleHabit(habit.id) } label: { Image(systemName: habit.completed(on: store.now) ? "checkmark.circle.fill" : "circle").font(.system(size: 23, weight: .light)).foregroundStyle(habit.completed(on: store.now) ? store.accentColor : Palette.secondary) }.buttonStyle(.plain).accessibilityLabel("\(habit.completed(on: store.now) ? "Uncheck" : "Complete") \(habit.title) for today")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(habit.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                    Text("\(habit.streak(at: store.now)) day streak").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                }
                                Spacer(minLength: 0)
                                iconButton("Rename \(habit.title)", symbol: "pencil") { editing = habit }
                                iconButton("Delete \(habit.title)", symbol: "trash") { deleting = habit }
                            }
                            HStack(spacing: 5) {
                                ForEach(-6...0, id: \.self) { offset in
                                    let day = Calendar.current.date(byAdding: .day, value: offset, to: store.now) ?? store.now
                                    let done = habit.completed(on: day)
                                    VStack(spacing: 3) {
                                        RoundedRectangle(cornerRadius: 3).fill(done ? store.accentColor : Palette.rule.opacity(0.09)).frame(height: 6)
                                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 8)).foregroundStyle(Palette.secondary)
                                    }.accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)): \(done ? "done" : "not done")")
                                }
                            }.padding(.leading, 33)
                        }.padding(.vertical, 12)
                        Divider()
                    }
                }
            }
        }.padding(14)
        .sheet(item: $editing) { HabitEditor(item: $0).environmentObject(store) }
        .alert("Delete this habit and its history?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete habit", role: .destructive) { if let deleting { store.removeHabit(deleting) }; deleting = nil }
        } message: { Text("You can undo this for 10 seconds.") }
    }
    private func add() { guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; store.addHabit(title); title = "" }
}

private struct HabitEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var item: DailyHabit
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename habit").font(.headline)
            PerchEntry("Habit name", text: $item.title)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { store.renameHabit(item.id, title: item.title); dismiss() }
                    .buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent).keyboardShortcut(.defaultAction)
                    .disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(20).frame(width: 320).tint(store.accentColor).accentColor(store.accentColor)
    }
}

struct BreathingWidgetView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var minutes = 1
    var body: some View {
        VStack(spacing: 12) {
            HStack { Text("Breathing").font(.system(size: 14, weight: .semibold)); Spacer(); if let session = store.breathingSession { Text(timeString(session.remaining(at: store.now))).monospacedDigit().foregroundStyle(Palette.secondary) } }
            if let session = store.breathingSession {
                if store.expanded && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in breathingCircle(session: session, at: context.date, animated: true) }
                } else { breathingCircle(session: session, at: store.now, animated: false) }
                Button("End session") { store.breathingSession = nil }.buttonStyle(.bordered)
            } else {
                breathingCircle(session: nil, at: store.now, animated: false)
                HStack { Picker("Duration", selection: $minutes) { ForEach([1, 2, 3, 5], id: \.self) { Text("\($0) min").tag($0) } }.labelsHidden().frame(width: 90); Spacer(); Button("Begin") { store.breathingSession = BreathingSession(minutes: minutes); store.now = Date() }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent) }
            }
            Text("In for 4 seconds, out for 6. Go at a comfortable pace.").font(.system(size: 10)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
        }.padding(14)
    }
    private func breathingCircle(session: BreathingSession?, at date: Date, animated: Bool) -> some View {
        ZStack {
            Circle().stroke(store.accentColor.opacity(0.25), lineWidth: 1).frame(width: 136, height: 136)
            Circle().fill(store.accentColor.opacity(0.14)).frame(width: 112, height: 112)
                .scaleEffect(animated ? 0.70 + 0.30 * (session?.expansion(at: date) ?? 1) : 1)
            VStack(spacing: 5) {
                Text(session == nil ? "A little pause" : session!.inhale(at: date) ? "Breathe in" : "Breathe out").font(.system(size: 14, weight: .medium))
                Text(session == nil ? "Ready when you are" : session!.inhale(at: date) ? "Gently" : "Let it go").font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }.frame(maxWidth: .infinity).frame(height: 148).accessibilityElement(children: .combine)
    }
}

struct AwakeWidgetView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var controller: AwakeController
    @State private var minutes = 30
    @State private var display = false
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text("Keep awake").font(.system(size: 14, weight: .semibold)); Spacer(); WidgetGlyph(widget: .awake).frame(width: 27, height: 27).foregroundStyle(store.accentColor) }
            if let end = controller.endsAt {
                Text("Awake until \(end.formatted(.dateTime.hour().minute()))").font(.system(size: 18, weight: .medium)).foregroundStyle(store.accentColor)
                Text(controller.keepsDisplayAwake ? "Mac and display stay awake." : "Your display can still dim and sleep.").font(.caption).foregroundStyle(Palette.secondary)
                Button("Stop keeping awake") { controller.stop() }.buttonStyle(.bordered)
            } else {
                Picker("Duration", selection: $minutes) { ForEach([15, 30, 60, 120, 180], id: \.self) { Text("\($0) minutes").tag($0) } }
                Toggle("Keep display awake too", isOn: $display).font(.system(size: 12))
                Button("Keep Mac awake") {
                    guard !store.demo else { store.showToast("Preview: power settings are unchanged"); return }
                    do { try controller.start(minutes: minutes, display: display) } catch { store.error = error.localizedDescription }
                }.buttonStyle(BlueActionStyle())
            }
            Text("Stops automatically or when Perch quits. Closing the lid can still put your Mac to sleep.").font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(14)
    }
}
