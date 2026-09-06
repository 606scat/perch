import AppKit
import SwiftUI
import Carbon
import PerchCore

struct ShortcutRecorder: NSViewRepresentable {
    var widget: DockWidget
    var store: AppStore
    func makeNSView(context: Context) -> ShortcutButton {
        let button = ShortcutButton()
        button.bezelStyle = .rounded; button.isBordered = false; button.controlSize = .small
        button.alignment = .center
        button.contentTintColor = .secondaryLabelColor
        button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = .systemFont(ofSize: 10, weight: .regular)
        button.target = button; button.action = #selector(ShortcutButton.beginRecording)
        return button
    }
    func updateNSView(_ button: ShortcutButton, context: Context) {
        button.store = store; button.widget = widget
        if !button.recording { button.title = store.data.preferences.widgetShortcuts[widget.rawValue]?.display ?? "Shortcut…" }
        button.contentTintColor = button.recording ? store.accentNSColor : .secondaryLabelColor
        button.toolTip = "Set a global shortcut for \(widget.title). Press Escape to cancel or Delete to clear."
        button.setAccessibilityLabel("Shortcut for \(widget.title)")
        button.setAccessibilityValue(button.title)
        button.invalidateIntrinsicContentSize()
    }
    static func dismantleNSView(_ button: ShortcutButton, coordinator: ()) { button.finish() }
}

@MainActor final class ShortcutButton: NSButton {
    weak var store: AppStore?
    var widget: DockWidget = .notes
    var recording = false
    override var acceptsFirstResponder: Bool { true }
    @objc func beginRecording() {
        window?.makeKey(); window?.makeFirstResponder(self)
        recording = true; store?.recordingShortcut = true; title = "Press keys…"; contentTintColor = store?.accentNSColor ?? .systemBlue
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { finish(); return }
        if event.keyCode == 51 || event.keyCode == 117 { store?.setShortcut(nil, for: widget); finish(); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .control, .option]).isEmpty else { title = "Include ⌘, ⌃ or ⌥"; return }
        var modifiers: UInt32 = 0
        var display = ""
        if flags.contains(.control) { modifiers |= UInt32(controlKey); display += "⌃" }
        if flags.contains(.option) { modifiers |= UInt32(optionKey); display += "⌥" }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey); display += "⇧" }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey); display += "⌘" }
        let names: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        display += names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        store?.setShortcut(WidgetShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, display: display), for: widget)
        finish()
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event); return true
    }
    override func resignFirstResponder() -> Bool { finish(); return super.resignFirstResponder() }
    func finish() {
        recording = false; store?.recordingShortcut = false
        title = store?.data.preferences.widgetShortcuts[widget.rawValue]?.display ?? "Shortcut…"
        contentTintColor = .secondaryLabelColor; setAccessibilityValue(title)
    }
}
