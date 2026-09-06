import AppKit
import SwiftUI
import PerchCore

private func swatchColor(_ hex: String) -> Color {
    let c = (try? ColorCode.components(hex)) ?? (red: 7, green: 95, blue: 183)
    return Color(red: Double(c.red) / 255, green: Double(c.green) / 255, blue: Double(c.blue) / 255)
}

struct ColorsWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var hex = "#47A8FF"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Color picker").font(.system(size: 14, weight: .semibold)); Spacer(); WidgetGlyph(widget: .colors).frame(width: 22, height: 22).foregroundStyle(store.accentColor) }
            Button("Pick from screen", systemImage: "eyedropper") { store.sampleColor() }.buttonStyle(BlueActionStyle())
            HStack {
                PerchEntry("#RRGGBB", text: $hex).font(.system(size: 13, design: .monospaced)).onSubmit { store.keepColor(hex) }
                Button("Keep") { store.keepColor(hex) }.buttonStyle(.bordered).disabled((try? ColorCode.normalize(hex)) == nil)
            }
            if store.play.swatches.isEmpty { Text("Pick a color anywhere on your screen, or enter a hex code. Keep up to 24.").font(.caption).foregroundStyle(Palette.secondary).padding(.top, 10) }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                    ForEach(store.play.swatches) { item in
                        Button { store.copyText(item.hex) } label: {
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 8).fill(swatchColor(item.hex)).frame(height: 34).overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.rule.opacity(0.15)))
                                Text(item.hex).font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.secondary)
                            }
                        }.buttonStyle(.plain).accessibilityLabel("Copy \(item.hex)")
                            .contextMenu {
                                Button("Copy hex") { store.copyText(item.hex) }
                                Button("Copy RGB") { if let rgb = try? ColorCode.rgb(item.hex) { store.copyText(rgb) } }
                                Button("Remove color") { store.removeColor(item) }
                            }
                    }
                }
            }
            Text("Click a color to copy. Right-click for RGB or remove.").font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }.padding(14)
    }
}

struct QRWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var png: Data?
    @State private var failure: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("QR code").font(.system(size: 14, weight: .semibold))
            Text("A link or short message, ready to scan.").font(.caption).foregroundStyle(Palette.secondary)
            TextEditor(text: Binding(get: { store.play.qrText }, set: { store.play.qrText = String($0.prefix(2000)) }))
                .font(.system(size: 12)).scrollContentBackground(.hidden).padding(6).frame(height: 65)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel("QR content")
            Group {
                if let png, let image = NSImage(data: png) { Image(nsImage: image).resizable().interpolation(.none).scaledToFit().padding(3).background(.white, in: RoundedRectangle(cornerRadius: 8)) }
                else { VStack(spacing: 10) { WidgetGlyph(widget: .qr).frame(width: 44, height: 44).foregroundStyle(store.accentColor); Text(failure ?? "Paste something above to make a QR code.").font(.caption).foregroundStyle(failure == nil ? Palette.secondary : Palette.error).multilineTextAlignment(.center) }.frame(maxWidth: .infinity) }
            }.frame(maxWidth: .infinity).frame(height: 175)
            HStack {
                Text("Generated on this Mac.").font(.system(size: 10)).foregroundStyle(Palette.secondary); Spacer()
                Button("Copy") { if let png { store.copyPNG(png) } }.buttonStyle(.bordered).disabled(png == nil)
                Button("Save") { if let png { store.savePNG(png, suggestedName: "Perch QR.png") } }.buttonStyle(.bordered).disabled(png == nil)
            }
        }.padding(14)
        .task(id: store.play.qrText) {
            png = nil; failure = nil
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            guard !store.play.qrText.isEmpty else { return }
            do { png = try QRRenderer.png(store.play.qrText) } catch { failure = error.localizedDescription }
        }
    }
}

struct TextToolsWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var transform = TextTransform.original
    @State private var stats = TextStatistics("")
    @State private var output = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Text tools").font(.system(size: 14, weight: .semibold))
            HStack(spacing: 14) {
                ForEach([("Words", stats.words), ("Characters", stats.characters), ("Lines", stats.lines)], id: \.0) { label, count in
                    VStack(alignment: .leading, spacing: 3) { Text(count.formatted()).font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(store.accentColor); Text(label).font(.system(size: 10)).foregroundStyle(Palette.secondary) }
                }
                Spacer(minLength: 0)
            }
            TextEditor(text: Binding(get: { store.play.textInput }, set: { store.play.textInput = String($0.prefix(65_536)) }))
                .font(.system(size: 12)).scrollContentBackground(.hidden).padding(6).frame(height: 110)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel("Text to count or transform")
            Picker("Copy as", selection: $transform) { ForEach(TextTransform.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            ScrollView { Text(output.isEmpty ? "Paste text above. Your source stays as you wrote it." : output).font(.system(size: 11)).foregroundStyle(output.isEmpty ? Palette.secondary : Palette.primary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 56)
            HStack { Text("Source stays unchanged.").font(.system(size: 10)).foregroundStyle(Palette.secondary); Spacer(); Button("Copy result") { store.copyText(output) }.buttonStyle(.bordered).disabled(output.isEmpty) }
        }.padding(14)
        .onAppear { refresh() }
        .onChange(of: store.play.textInput) { _, _ in refresh() }
        .onChange(of: transform) { _, _ in output = transform.apply(to: store.play.textInput) }
    }
    private func refresh() { stats = TextStatistics(store.play.textInput); output = transform.apply(to: store.play.textInput) }
}

struct DecisionsWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var mode = 0
    @State private var result: String?
    @State private var die = 1
    private var options: [String] { Decisions.options(from: store.play.decisionOptions) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick decisions").font(.system(size: 14, weight: .semibold))
            Picker("Decision type", selection: $mode) { Text("Coin").tag(0); Text("Dice").tag(1); Text("Pick one").tag(2) }.pickerStyle(.segmented).onChange(of: mode) { _, _ in result = nil }
            if mode == 2 {
                TextEditor(text: Binding(get: { store.play.decisionOptions }, set: { store.play.decisionOptions = String($0.prefix(12_000)) }))
                    .font(.system(size: 12)).scrollContentBackground(.hidden).padding(6).frame(height: 70).background(Palette.field, in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel("Options, one per line")
                Text("One option per line · \(options.count) choices").font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 0)
            Group {
                if mode == 1, result != nil { Image(systemName: "die.face.\(die).fill").font(.system(size: 58)).foregroundStyle(store.accentColor).accessibilityLabel("Rolled \(die)") }
                else { ScrollView { Text(result ?? (mode == 2 ? "Add two choices to begin." : "Let a little chance decide."))
                    .font(.system(size: result == nil ? 14 : 26, weight: .medium, design: .rounded)).foregroundStyle(result == nil ? Palette.secondary : store.accentColor).multilineTextAlignment(.center).frame(maxWidth: .infinity) } }
            }.frame(maxWidth: .infinity).frame(height: mode == 2 ? 58 : 94)
            Spacer(minLength: 0)
            Button(mode == 0 ? "Flip a coin" : mode == 1 ? "Roll a die" : "Pick one") {
                if mode == 0 { result = Bool.random() ? "Heads" : "Tails" }
                else if mode == 1 { die = Int.random(in: 1...6); result = String(die) }
                else { var generator = SystemRandomNumberGenerator(); result = Decisions.choose(from: options, using: &generator) }
                store.sounds.play(.drop, preferences: store.data.preferences)
            }.buttonStyle(BlueActionStyle()).disabled(mode == 2 && options.count < 2)
        }.padding(14)
    }
}

struct DoodleWidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var points: [DrawingPoint] = []
    @State private var ink = "#075FB7"
    @State private var clearing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { Text("Doodle").font(.system(size: 14, weight: .semibold)); Spacer(); iconButton("Undo last stroke", symbol: "arrow.uturn.backward") { if !store.play.strokes.isEmpty { store.play.strokes.removeLast() } }.disabled(store.play.strokes.isEmpty); iconButton("Clear canvas", symbol: "trash") { clearing = true }.disabled(store.play.strokes.isEmpty) }
            GeometryReader { geometry in
                Canvas { context, size in
                    for stroke in store.play.strokes + (points.isEmpty ? [] : [DoodleStroke(points: points, hex: ink)]) {
                        guard let first = stroke.points.first else { continue }
                        var path = Path(); let initial = CGPoint(x: first.x * size.width, y: first.y * size.height)
                        if stroke.points.count == 1 { path.addEllipse(in: CGRect(x: initial.x - 1.25, y: initial.y - 1.25, width: 2.5, height: 2.5)); context.fill(path, with: .color(swatchColor(stroke.hex))) }
                        else { path.move(to: initial); for point in stroke.points.dropFirst() { path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height)) }; context.stroke(path, with: .color(swatchColor(stroke.hex)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)) }
                    }
                }.background(.white).clipShape(RoundedRectangle(cornerRadius: 9)).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let point = DrawingPoint(x: value.location.x / max(1, geometry.size.width), y: value.location.y / max(1, geometry.size.height))
                        if points.count < 400, points.last.map({ $0.distance(to: point) > 0.003 }) ?? true { points.append(point) }
                    }.onEnded { _ in store.addStroke(DoodleStroke(points: points, hex: ink)); points = [] })
                    .accessibilityLabel("Doodle canvas, \(store.play.strokes.count) strokes. Draw with your mouse or trackpad.")
            }.frame(height: 177)
            HStack(spacing: 9) {
                ForEach(["#075FB7", "#20252B", "#B52D64", "#26713D"], id: \.self) { color in
                    Button { ink = color } label: { Circle().fill(swatchColor(color)).frame(width: 18, height: 18).padding(3).overlay(Circle().stroke(ink == color ? store.accentColor : .clear, lineWidth: 1.5)) }.buttonStyle(.plain).accessibilityLabel("Ink \(color)")
                }
                Spacer()
                Button("Save PNG") { if let data = DoodleRenderer.png(store.play.strokes) { store.savePNG(data, suggestedName: "Perch Doodle.png") } }.buttonStyle(.bordered).disabled(store.play.strokes.isEmpty)
            }
            Text("A tiny canvas. Saved automatically on this Mac.").font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }.padding(14)
        .alert("Clear this doodle?", isPresented: $clearing) {
            Button("Cancel", role: .cancel) {}
            Button("Clear canvas", role: .destructive) { let old = store.play.strokes; store.play.strokes = []; store.offerUndo("Canvas cleared") { store.play.strokes = old + store.play.strokes } }
        } message: { Text("Undo is available for 10 seconds. Saved PNG files stay in place.") }
    }
}

struct GardenWidgetView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 10) {
            HStack { Text("Tiny garden").font(.system(size: 14, weight: .semibold)); Spacer(); Text("Just because").font(.system(size: 10)).foregroundStyle(Palette.secondary) }
            TinyPlant(stage: store.play.garden.stage).frame(height: 165).animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: store.play.garden.stage)
            Text(store.play.garden.stageName).font(.system(size: 16, weight: .medium, design: .rounded))
            Text("Water daily or finish a focus session to help it grow.").font(.system(size: 11)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button(store.play.garden.canWater(at: store.now) ? "Water your plant" : "Watered today") {
                if store.play.garden.water(at: Date()) { store.sounds.play(.drop, preferences: store.data.preferences) }
            }.buttonStyle(.bordered).disabled(!store.play.garden.canWater(at: store.now))
        }.padding(14)
    }
}

private struct TinyPlant: View {
    var stage: Int
    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(.black.opacity(0.1)).frame(width: 130, height: 15).offset(y: 5)
            if stage > 0 {
                Capsule().fill(Color(red: 0.30, green: 0.56, blue: 0.38)).frame(width: 4, height: CGFloat(32 + stage * 20)).offset(y: -38)
                ForEach(0..<(stage * 2), id: \.self) { index in
                    Ellipse().fill(Color(red: 0.34 + Double(index % 2) * 0.10, green: 0.64, blue: 0.43))
                        .frame(width: CGFloat(29 + stage * 4), height: CGFloat(14 + stage * 2))
                        .rotationEffect(.degrees(index % 2 == 0 ? -28 : 28))
                        .offset(x: index % 2 == 0 ? -18 : 18, y: CGFloat(-49 - index / 2 * 21))
                }
            } else { Capsule().fill(Color(red: 0.48, green: 0.32, blue: 0.19)).frame(width: 14, height: 8).offset(y: -38) }
            RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.54, green: 0.39, blue: 0.29)).frame(width: 74, height: 40)
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.66, green: 0.49, blue: 0.36)).frame(width: 86, height: 11).offset(y: -32)
        }.frame(maxWidth: .infinity).accessibilityHidden(true)
    }
}
