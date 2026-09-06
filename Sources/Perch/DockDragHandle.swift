import AppKit
import SwiftUI

struct DockDragHandle: NSViewRepresentable {
    var store: AppStore
    func makeNSView(context: Context) -> GripView {
        let view = GripView(); view.store = store
        view.setAccessibilityLabel("Move Perch to another screen edge")
        view.setAccessibilityRole(.handle)
        view.setAccessibilityElement(true)
        return view
    }
    func updateNSView(_ nsView: GripView, context: Context) { nsView.store = store }
}

@MainActor final class GripView: NSView {
    weak var store: AppStore?
    private var mouseStart = NSPoint.zero
    private var windowStart = NSPoint.zero
    private var moved = false
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.withAlphaComponent(0.6).setFill()
        for x in [-3.0, 3.0] {
            for y in [-4.0, 0.0, 4.0] {
                NSBezierPath(ovalIn: NSRect(x: bounds.midX + x - 0.8, y: bounds.midY + y - 0.8, width: 1.6, height: 1.6)).fill()
            }
        }
    }
    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation; windowStart = window?.frame.origin ?? .zero
        moved = false; store?.dragBegan?(); NSCursor.closedHand.push()
    }
    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        if hypot(current.x - mouseStart.x, current.y - mouseStart.y) > 3 { moved = true }
        window?.setFrameOrigin(NSPoint(x: windowStart.x + current.x - mouseStart.x, y: windowStart.y + current.y - mouseStart.y))
    }
    override func mouseUp(with event: NSEvent) {
        NSCursor.pop()
        if moved { store?.dragEnded?() }
        else { store?.isDragging = false; store?.hoverChanged?(true) }
    }
}
