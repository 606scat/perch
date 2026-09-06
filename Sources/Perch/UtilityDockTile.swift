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
            }.font(.system(size: 8, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            Text(widget.title).font(.system(size: 6.5)).foregroundStyle(Palette.secondary).lineLimit(1)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var summary: String {
        switch widget {
        case .clipboard: store.utilities.clips.isEmpty ? "Keep text" : "\(store.utilities.clips.count) clips"
        case .calculator: store.utilities.calculations.first?.result ?? "Quick math"
        case .converter: "Convert"
        case .clocks: "\(store.utilities.clockZones.count) cities"
        case .countdowns:
            if let date = store.utilities.milestones.filter({ $0.days(from: store.now) >= 0 }).min(by: { $0.date < $1.date }) { "\(date.days(from: store.now)) days" } else { "Pick a date" }
        case .habits: "\(store.utilities.habits.filter { $0.completed(on: store.now) }.count)/\(store.utilities.habits.count) today"
        case .breathing: store.breathingSession.map { timeString($0.remaining(at: store.now)) } ?? "Take a pause"
        case .awake: "Stay awake"
        default: widget.title
        }
    }
}

private struct AwakeDockSummary: View {
    @ObservedObject var controller: AwakeController
    var body: some View { Text(controller.endsAt == nil ? "Off" : "Awake") }
}
