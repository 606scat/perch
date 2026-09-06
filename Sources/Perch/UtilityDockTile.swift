import SwiftUI
import PerchCore

struct UtilityDockTile: View {
    @EnvironmentObject var store: AppStore
    var widget: DockWidget
    var selected: Bool
    var body: some View {
        VStack(spacing: 3) {
            WidgetGlyph(widget: widget).frame(width: 23, height: 23).foregroundStyle(selected ? store.accentColor : Palette.primary)
            Group {
                if widget == .awake { AwakeDockSummary(controller: store.awake) }
                else { Text(summary) }
            }.font(.system(size: 8, weight: .medium)).lineLimit(1).minimumScaleFactor(0.65).allowsTightening(true)
            Text(widget.tileTitle).font(.system(size: 6.5)).foregroundStyle(Palette.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var summary: String {
        switch widget {
        case .clipboard: store.utilities.clips.isEmpty ? "Keep text" : "\(store.utilities.clips.count) clips"
        case .calculator:
            if let result = store.utilities.calculations.first?.result, let value = Double(result) { result.count > 8 ? String(format: "%.3g", value) : result } else { "Ready" }
        case .converter: "Convert"
        case .clocks: "\(store.utilities.clockZones.count) cities"
        case .countdowns:
            if let date = store.utilities.milestones.filter({ $0.days(from: store.now) >= 0 }).min(by: { $0.date < $1.date }) { "\(date.days(from: store.now))d" } else { "Ready" }
        case .habits: "\(store.utilities.habits.filter { $0.completed(on: store.now) }.count)/\(store.utilities.habits.count)"
        case .breathing: store.breathingSession.map { timeString($0.remaining(at: store.now)) } ?? "Unwind"
        case .awake: "Stay awake"
        case .colors: store.play.swatches.first?.hex ?? "Pick"
        case .qr: store.play.qrText.isEmpty ? "Create" : "Ready"
        case .textTools: "Count"
        case .decisions: "Choose"
        case .doodle: "Draw"
        case .garden: ["Seed", "Sprout", "Growing", "Leafy", "Lush"][store.play.garden.stage]
        default: widget.title
        }
    }
}

private struct AwakeDockSummary: View {
    @ObservedObject var controller: AwakeController
    var body: some View { Text(controller.endsAt == nil ? "Off" : "Awake") }
}
