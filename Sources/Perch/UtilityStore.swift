import AppKit
import PerchCore

extension AppStore {
    var utilities: UtilityData {
        get { data.utilities ?? UtilityData() }
        set { data.utilities = newValue }
    }
    func copyText(_ text: String, message: String = "Copied") {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { error = "The clipboard couldn’t be updated. Try copying again."; return }
        sounds.play(.copy, preferences: data.preferences); showToast(message)
    }
    func captureClipboard(from supplied: NSPasteboard? = nil) {
        if demo && supplied == nil { showToast("Preview: clipboard capture is disabled"); return }
        let pasteboard = supplied ?? .general
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        guard pasteboard.types?.contains(concealed) != true, pasteboard.types?.contains(transient) != true else {
            error = "The source app marked this copied content as private or temporary. Perch won’t keep it."; return
        }
        do { try utilities.capture(pasteboard.string(forType: .string) ?? ""); showToast("Copied text kept") }
        catch { self.error = error.localizedDescription }
    }
    func removeClip(_ clip: ClipboardClip) {
        let index = utilities.clips.firstIndex(where: { $0.id == clip.id }) ?? 0
        utilities.clips.removeAll { $0.id == clip.id }
        offerUndo("Clipboard item removed") { [weak self] in
            guard let self, !self.utilities.clips.contains(where: { $0.id == clip.id }) else { return }
            self.utilities.clips.insert(clip, at: min(index, self.utilities.clips.count))
        }
    }
    @discardableResult func calculate() -> String? {
        do {
            let expression = utilities.calculatorInput
            let result = Calculator.format(try Calculator.evaluate(expression))
            if utilities.calculations.first?.expression != expression || utilities.calculations.first?.result != result {
                utilities.calculations.insert(Calculation(expression: expression, result: result), at: 0)
                utilities.calculations = Array(utilities.calculations.prefix(20))
            }
            return result
        } catch { self.error = error.localizedDescription; return nil }
    }
    func saveMilestone(_ item: Milestone) {
        var item = item; item.title = String(item.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !item.title.isEmpty else { return }
        if let index = utilities.milestones.firstIndex(where: { $0.id == item.id }) { utilities.milestones[index] = item }
        else if utilities.milestones.count < 50 { utilities.milestones.append(item) }
        else { error = "You have 50 countdowns. Remove one before adding another." }
    }
    func removeMilestone(_ item: Milestone) {
        utilities.milestones.removeAll { $0.id == item.id }
        offerUndo("Countdown removed") { [weak self] in self?.utilities.milestones.append(item) }
    }
    func addHabit(_ title: String) {
        let title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !title.isEmpty else { return }
        guard utilities.habits.count < 24 else { error = "You have 24 habits. Remove one before adding another."; return }
        utilities.habits.append(DailyHabit(title: title))
    }
    func toggleHabit(_ id: UUID, at date: Date = Date()) {
        guard let index = utilities.habits.firstIndex(where: { $0.id == id }) else { return }
        utilities.habits[index].toggle(on: date)
        if utilities.habits[index].completed(on: date) { sounds.play(.complete, preferences: data.preferences) }
    }
    func renameHabit(_ id: UUID, title: String) {
        let title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !title.isEmpty, let index = utilities.habits.firstIndex(where: { $0.id == id }) else { return }
        utilities.habits[index].title = title
    }
    func removeHabit(_ item: DailyHabit) {
        let index = utilities.habits.firstIndex(where: { $0.id == item.id }) ?? 0
        utilities.habits.removeAll { $0.id == item.id }
        offerUndo("Habit removed") { [weak self] in guard let self else { return }; self.utilities.habits.insert(item, at: min(index, self.utilities.habits.count)) }
    }
}
