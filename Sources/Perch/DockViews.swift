import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PerchCore

extension DockWidget {
    var section: Section {
        switch self {
        case .focus: .focus; case .today: .today; case .notes: .notes; case .tray: .tray; case .snippets: .snippets; case .projects: .projects
        case .clipboard: .clipboard; case .calculator: .calculator; case .converter: .converter; case .clocks: .clocks
        case .countdowns: .countdowns; case .habits: .habits; case .breathing: .breathing; case .awake: .awake
        case .colors: .colors; case .qr: .qr; case .textTools: .textTools; case .decisions: .decisions; case .doodle: .doodle; case .garden: .garden
        }
    }
    var summary: String {
        switch self {
        case .focus: "Set a focus timer for your current task."
        case .today: "Manage Reminders tasks and pin three daily priorities."
        case .notes: "Write, edit, and save quick notes."
        case .tray: "Hold files to drag into other apps."
        case .snippets: "Save reusable text and copy it in one click."
        case .projects: "Group and open links, apps, and folders."
        case .clipboard: "Keep copied text and paste it again later."
        case .calculator: "Calculate, reuse history, and copy results."
        case .converter: "Convert length, weight, temperature, and more."
        case .clocks: "Compare cities and preview a meeting time."
        case .countdowns: "Count the days to dates that matter."
        case .habits: "Check in daily and see your streaks."
        case .breathing: "Unwind with sounds and guided breathwork."
        case .awake: "Keep your Mac awake for a chosen duration."
        case .colors: "Pick screen colors and keep a small palette."
        case .qr: "Turn a link or text into a scannable code."
        case .textTools: "Count words and copy text in a new format."
        case .decisions: "Flip a coin, roll a die, or pick an option."
        case .doodle: "Draw a little something and save it."
        case .garden: "Water a tiny plant and watch it grow."
        }
    }
}

struct DockMaterial: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = colorScheme == .dark ? .hudWindow : .popover; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        let material: NSVisualEffectView.Material = colorScheme == .dark ? .hudWindow : .popover
        if nsView.material != material { nsView.material = material }
    }
}

extension View {
    func dockSurface(cornerRadius: CGFloat) -> some View {
        self.background {
            PerchSurface(rail: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Palette.rule.opacity(0.17), lineWidth: 0.7))
    }
}

struct DockRailContainer: View {
    @EnvironmentObject var store: AppStore
    private var alignment: Alignment {
        switch store.data.preferences.dockEdge {
        case .left: .trailing
        case .right: .leading
        case .top: .bottom
        case .bottom: .top
        }
    }
    var body: some View {
        GeometryReader { geometry in
            DockRail().frame(width: store.dockSize.width, height: store.dockSize.height)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
                .clipped()
                .contentShape(Rectangle())
        }
        .onHover { store.dockHoverChanged?($0) }
        .accessibilityElement(children: store.dockRevealed ? .contain : .ignore)
        .accessibilityLabel(store.dockRevealed ? "Perch dock" : "Show Perch dock")
        .accessibilityAddTraits(store.dockRevealed ? [] : .isButton)
        .accessibilityAction { store.revealDockCommand?() }
    }
}

struct DockRail: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminders: ReminderStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    private var vertical: Bool { store.data.preferences.dockEdge.isVertical }
    private var overflowing: Bool { CGFloat(54 + store.data.preferences.widgets.count * (vertical ? 60 : 58)) > store.dockLengthLimit }
    var body: some View {
        let layout = store.data.preferences.dockEdge.isVertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        layout {
            DockDragHandle(store: store)
                .frame(width: store.data.preferences.dockEdge.isVertical ? 40 : 14, height: store.data.preferences.dockEdge.isVertical ? 14 : 40)
                .help("Drag to any screen edge")
            if overflowing {
                ScrollViewReader { reader in
                    ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) { tiles }
                        .onChange(of: store.section) { _, _ in revealSelection(reader) }
                        .onChange(of: store.expanded) { _, expanded in if expanded { revealSelection(reader) } }
                }
                .frame(width: vertical ? 52 : max(0, store.dockSize.width - 60), height: vertical ? max(0, store.dockSize.height - 60) : 54)
                .help("Scroll to reach more widgets")
            } else { tiles }
            Button {
                store.togglePanel(.widgets)
            } label: {
                Image(systemName: store.editingWidgets ? "square.grid.2x2" : "plus").font(.system(size: 13, weight: .medium))
                    .foregroundStyle(store.expanded && store.section == .widgets ? store.accentColor : Palette.secondary).frame(width: vertical ? 52 : 22, height: vertical ? 22 : 52)
            }.buttonStyle(.plain).help("Add or remove widgets").accessibilityLabel("Add or remove widgets")
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "PerchRail")
        .onPreferenceChange(WidgetOffsetPreference.self) { if store.widgetOffsets != $0 { store.widgetOffsets = $0 } }
        .dockSurface(cornerRadius: 16)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.88), value: store.data.preferences.widgets)
        .accentColor(store.accentColor)
        .foregroundStyle(Palette.primary)
    }
    private func revealSelection(_ reader: ScrollViewProxy) {
        guard let widget = DockWidget.allCases.first(where: { $0.section == store.section }), store.data.preferences.widgets.contains(widget) else { return }
        let offset = store.widgetOffsets[widget] ?? -1
        let length = vertical ? store.dockSize.height : store.dockSize.width
        if offset < 52 || offset > length - 52 { reader.scrollTo(widget, anchor: .center) }
    }
    private var tiles: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            ForEach(store.data.preferences.widgets) { widget in
                DockTile(widget: widget, selected: store.expanded && store.section == widget.section)
                    .id(widget)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: WidgetOffsetPreference.self, value: [widget: vertical ? geometry.frame(in: .named("PerchRail")).midY : geometry.frame(in: .named("PerchRail")).midX])
                    })
                    .overlay(alignment: .topTrailing) {
                        if store.editingWidgets {
                            Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { store.toggleWidget(widget) } } label: {
                                Image(systemName: "minus").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 17, height: 17).background(Color(red: 0.8, green: 0.25, blue: 0.28), in: Circle())
                            }.buttonStyle(.plain).offset(x: 5, y: -5).help("Remove \(widget.title) widget")
                        }
                    }
                    .onTapGesture { store.activateWidgetShortcut(widget) }
                    .onHover { inside in
                        if inside { store.hoveredWidget = widget }
                        else if store.hoveredWidget == widget { store.hoveredWidget = nil }
                        guard inside, store.dockRevealed, !store.editingWidgets, !store.isDragging, store.canHoverSwitch?() != false else { return }
                        store.section = widget.section
                        store.hoverChanged?(true)
                    }
                    .onDrag {
                        store.draggedWidget = widget
                        let provider = NSItemProvider()
                        provider.registerDataRepresentation(forTypeIdentifier: "local.af.perch.widget", visibility: .ownProcess) { completion in
                            completion(Data(widget.rawValue.utf8), nil); return nil
                        }
                        return provider
                    }
                    .onDrop(of: [UTType(exportedAs: "local.af.perch.widget")], delegate: WidgetReorderDrop(target: widget, store: store))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(widget.title) widget")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { store.activateWidgetShortcut(widget) }
                    .contextMenu {
                        Button("Open \(widget.title)") { store.section = widget.section; store.expanded = true; store.activatePanel?() }
                        Button("Edit widgets") { store.section = .widgets; store.expanded = true; store.editingWidgets = true; store.activatePanel?() }
                        Button("Quick capture") { store.activatePanel?(); store.capturePresented = true }
                        Button("Remove widget") { store.toggleWidget(widget) }
                    }
            }
        }
    }
}

private struct WidgetOffsetPreference: PreferenceKey {
    static var defaultValue: [DockWidget: CGFloat] = [:]
    static func reduce(value: inout [DockWidget: CGFloat], nextValue: () -> [DockWidget: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

struct DockTile: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminders: ReminderStore
    var widget: DockWidget
    var selected = false
    @State private var hovering = false
    var body: some View {
        VStack(spacing: 2) {
            switch widget {
            case .focus:
                ZStack {
                    RoundedRectangle(cornerRadius: 8).stroke(Palette.rule.opacity(0.10), lineWidth: 2)
                    RoundedRectangle(cornerRadius: 8)
                        .trim(from: 0, to: store.data.focus.map { min(1, max(0.02, $0.remaining(at: store.now) / $0.duration)) } ?? 1)
                        .stroke(store.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    WidgetGlyph(widget: .focus).frame(width: 19, height: 19).foregroundStyle(selected ? store.accentColor : Palette.rule.opacity(0.9))
                }.frame(width: 31, height: 29)
                Text(store.data.focus.map { timeString($0.remaining(at: store.now)) } ?? "\(store.data.preferences.focusMinutes):00")
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(Palette.primary)
                Text(store.data.focus.map { $0.isRunning ? "Focusing" : "Paused" } ?? "Ready").font(.system(size: 6.5)).foregroundStyle(Palette.secondary).lineLimit(1)
            case .today:
                HStack { Text("Today").font(.system(size: 8, weight: .semibold)).foregroundStyle(selected ? store.accentColor : Palette.primary); Spacer() }
                if reminders.authorized {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(reminders.items.count)").font(.system(size: 22, weight: .medium, design: .rounded))
                        Text("tasks").font(.system(size: 7)).foregroundStyle(Palette.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 3) { ForEach(0..<3) { i in Circle().fill(i < store.data.priorityIDs.count ? store.accentColor : Palette.rule.opacity(0.2)).frame(width: 4, height: 4) }; Spacer() }
                } else {
                    WidgetGlyph(widget: .today).frame(width: 21, height: 21).foregroundStyle(selected ? store.accentColor : Palette.rule.opacity(0.7))
                    Text("Connect").font(.system(size: 7)).foregroundStyle(Palette.secondary)
                }
            case .notes:
                HStack { Text("Notes").font(.system(size: 8, weight: .semibold)).foregroundStyle(selected ? store.accentColor : Palette.primary); Spacer(minLength: 2); WidgetGlyph(widget: .notes).frame(width: 10, height: 10).foregroundStyle(selected ? store.accentColor : Palette.secondary) }
                if store.data.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach([34.0, 27, 19], id: \.self) { length in RoundedRectangle(cornerRadius: 1).fill(Palette.rule.opacity(0.2)).frame(width: length, height: 1) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    Text("A clear page").font(.system(size: 6.5)).foregroundStyle(Palette.secondary)
                } else {
                    Text("\(store.data.notes.count)").font(.system(size: 22, weight: .medium, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading)
                    Text(store.data.notes.count == 1 ? "saved note" : "saved notes").font(.system(size: 6.5)).foregroundStyle(Palette.secondary)
                }
            case .tray:
                WidgetGlyph(widget: .tray).frame(width: 26, height: 26).foregroundStyle(selected ? store.accentColor : Palette.rule.opacity(0.75)).padding(.top, 3)
                Text(store.data.tray.isEmpty ? "Drop files" : "\(store.data.tray.count) \(store.data.tray.count == 1 ? "file" : "files")").font(.system(size: 8, weight: .medium)).padding(.top, 3)
            case .snippets:
                HStack { Text("Snippets").font(.system(size: 7, weight: .semibold)).foregroundStyle(selected ? store.accentColor : Palette.primary); Spacer() }
                WidgetGlyph(widget: .snippets).frame(width: 24, height: 24).foregroundStyle(selected ? store.accentColor : Palette.rule.opacity(0.75))
                Text(store.data.snippets.isEmpty ? "Pin a reply" : "\(store.data.snippets.count) saved").font(.system(size: 6.5)).foregroundStyle(Palette.secondary).lineLimit(1)
            case .projects:
                HStack { Text("Projects").font(.system(size: 7, weight: .semibold)).foregroundStyle(selected ? store.accentColor : Palette.primary); Spacer() }
                let projects = Array(Set(store.data.links.map(\.project))).sorted()
                if projects.isEmpty {
                    WidgetGlyph(widget: .projects).frame(width: 25, height: 25).foregroundStyle(selected ? store.accentColor : Palette.rule.opacity(0.7)).padding(.top, 5)
                } else {
                    Text("\(projects.count)").font(.system(size: 22, weight: .medium, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Open").font(.system(size: 6.5)).foregroundStyle(Palette.secondary)
                }
            case .clipboard, .calculator, .converter, .clocks, .countdowns, .habits, .breathing, .awake, .colors, .qr, .textTools, .decisions, .doodle, .garden:
                UtilityDockTile(widget: widget, selected: selected)
            }
        }
        .padding(5).frame(width: 52, height: 54)
        .background(Palette.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? store.accentColor.opacity(0.85) : Palette.rule.opacity(hovering ? 0.28 : 0.1), lineWidth: selected ? 1.3 : 0.65))
        .scaleEffect(hovering && !store.editingWidgets ? 1.025 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
        .help(widget == .focus ? (store.data.focus?.title ?? "Focus") : widget.title)
    }
}

struct WidgetReorderDrop: DropDelegate {
    var target: DockWidget
    var store: AppStore
    func validateDrop(info: DropInfo) -> Bool { store.draggedWidget != nil }
    func dropEntered(info: DropInfo) {
        guard let source = store.draggedWidget, source != target,
              let from = store.data.preferences.widgets.firstIndex(of: source),
              let to = store.data.preferences.widgets.firstIndex(of: target) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            store.data.preferences.widgets.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { store.draggedWidget = nil; return true }
}

struct WidgetGallery: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @State private var onlyAdded = false
    private var matches: [DockWidget] {
        DockWidget.libraryOrder.filter { (!onlyAdded || store.data.preferences.widgets.contains($0)) && (query.isEmpty || ($0.title + " " + $0.summary).localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Widgets").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    iconButton("Settings", symbol: "slider.horizontal.3") { store.section = .settings }
                    Button("Done") { store.editingWidgets = false; store.expanded = false }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent)
                }
                Text("Add widgets. Drag the dock tiles to reorder.").font(.system(size: 11)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    PerchEntry("Find widgets", text: $query).font(.system(size: 11))
                    Toggle("On dock", isOn: $onlyAdded).toggleStyle(.button).font(.system(size: 11))
                }
                ScrollView {
                if matches.isEmpty { Text("No widgets match. Try another name.").font(.caption).foregroundStyle(Palette.secondary).padding(.vertical, 20) }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(matches) { widget in
                        let enabled = store.data.preferences.widgets.contains(widget)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 7) {
                                WidgetGlyph(widget: widget).frame(width: 20, height: 20).foregroundStyle(enabled ? store.accentColor : Palette.secondary)
                                Text(widget.title).font(.system(size: 12, weight: .semibold))
                                Spacer(minLength: 0)
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { store.toggleWidget(widget) } } label: {
                                    Image(systemName: enabled ? "minus" : "plus").font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(enabled ? Palette.secondary : Palette.onAccent)
                                        .frame(width: 22, height: 22).background(enabled ? Palette.rule.opacity(0.08) : store.accentColor, in: Circle())
                                }.buttonStyle(.plain).help(enabled ? "Remove \(widget.title)" : "Add \(widget.title)")
                                    .accessibilityLabel(enabled ? "Remove \(widget.title)" : "Add \(widget.title)")
                            }
                            Text(widget.summary).font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true).frame(minHeight: 26, alignment: .topLeading)
                            HStack { Spacer(minLength: 0); ShortcutRecorder(widget: widget, store: store).fixedSize(horizontal: true, vertical: false).frame(height: 19) }
                            if let error = store.shortcutErrors[widget.rawValue] { Text(error).font(.system(size: 9)).foregroundStyle(Palette.warning).fixedSize(horizontal: false, vertical: true) }
                        }.padding(10).frame(maxWidth: .infinity, alignment: .topLeading)
                            .background(Palette.rule.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                }
                Text("\(DockWidget.allCases.count) widgets · Shortcuts also open hidden widgets.").font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }.padding(14)
        .onAppear { store.editingWidgets = true }
        .onDisappear { store.editingWidgets = false }
    }
}

struct FocusDetailView: View {
    @EnvironmentObject var store: AppStore
    @State private var stopConfirmation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let focus = store.data.focus {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        ScrollView { Text(focus.title).font(.system(size: 11, weight: .medium)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 30)
                        Text(focus.isRunning ? "Focusing" : "Paused").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(timeString(focus.remaining(at: store.now))).font(.system(size: 14, weight: .medium, design: .monospaced))
                    iconButton(focus.isRunning ? "Pause focus" : "Resume focus", symbol: focus.isRunning ? "pause.fill" : "play.fill") { store.toggleFocus() }
                    iconButton("Stop focus", symbol: "stop.fill") { stopConfirmation = true }
                }
                ProgressView(value: min(1, max(0, 1 - focus.remaining(at: store.now) / focus.duration))).tint(store.accentColor)
            } else {
                Text("Focus").font(.system(size: 12, weight: .semibold))
                Text("Choose a task or make a little time to focus.").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                HStack {
                    Picker("Minutes", selection: $store.data.preferences.focusMinutes) { ForEach([15, 25, 45, 60, 90], id: \.self) { Text("\($0) min").tag($0) } }.labelsHidden().frame(width: 90)
                    Spacer()
                    Button("Start", systemImage: "play.fill") { store.startFocus(title: "Uninterrupted time") }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent)
                }
            }
        }.padding(14)
        .alert("Stop this focus session?", isPresented: $stopConfirmation) {
            Button("Keep focusing", role: .cancel) {}
            Button("Stop session", role: .destructive) { store.stopFocus() }
        } message: { Text("Your task stays in Reminders. Only this timer will stop.") }
    }
}

struct FlyoutShape: Shape {
    var edge: DockEdge
    var pointerOffset: CGFloat
    var animatableData: CGFloat { get { pointerOffset } set { pointerOffset = newValue } }
    func path(in rect: CGRect) -> Path {
        let body = rect.insetBy(dx: 8, dy: 8)
        var path = Path(roundedRect: body, cornerRadius: 15)
        let center = edge.isVertical ? CGPoint(x: rect.midX, y: pointerOffset) : CGPoint(x: pointerOffset, y: rect.midY)
        switch edge {
        case .left:
            path.move(to: CGPoint(x: body.minX + 1, y: center.y - 8)); path.addLine(to: CGPoint(x: 0, y: center.y)); path.addLine(to: CGPoint(x: body.minX + 1, y: center.y + 8))
        case .right:
            path.move(to: CGPoint(x: body.maxX - 1, y: center.y - 8)); path.addLine(to: CGPoint(x: rect.maxX, y: center.y)); path.addLine(to: CGPoint(x: body.maxX - 1, y: center.y + 8))
        case .top:
            path.move(to: CGPoint(x: center.x - 8, y: body.minY + 1)); path.addLine(to: CGPoint(x: center.x, y: 0)); path.addLine(to: CGPoint(x: center.x + 8, y: body.minY + 1))
        case .bottom:
            path.move(to: CGPoint(x: center.x - 8, y: body.maxY - 1)); path.addLine(to: CGPoint(x: center.x, y: rect.maxY)); path.addLine(to: CGPoint(x: center.x + 8, y: body.maxY - 1))
        }
        path.closeSubpath()
        return path
    }
}
