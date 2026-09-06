import AppKit
import Carbon
import Combine
import SwiftUI
import QuartzCore
import PerchCore
import QuickLookUI

final class PerchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var dismissFlyout: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { dismissFlyout?() }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var store: AppStore!
    private var panel: PerchPanel!
    private var dockPanel: PerchPanel!
    private var status: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var hotKey: EventHotKeyRef?
    private var widgetHotKeys: [String: EventHotKeyRef] = [:]
    private var openedByCommand = false
    private var dockOpenedByCommand = false
    private var eventHandler: EventHandlerRef?
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var hoverTask: Task<Void, Never>?
    private var retractTask: Task<Void, Never>?
    private var lastDrag = Date.distantPast
    private var menuTracking = false
    private var resizing = false
    private var animationGeneration = 0
    private var dataLease: PersistenceLease?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let demo = CommandLine.arguments.contains("--demo")
        do { dataLease = try PersistenceLease(dataURL: Persistence.defaultDataURL(demo: demo)) }
        catch {
            let alert = NSAlert()
            alert.messageText = "Perch couldn’t open your data"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK"); alert.runModal()
            NSApp.terminate(nil); return
        }
        store = AppStore(demo: demo)
        NSApp.appearance = store.data.preferences.theme.appearance
        store.hoverChanged = { [weak self] inside in self?.hover(inside, pointerEvent: true) }
        store.dockHoverChanged = { [weak self] inside in self?.dockHover(inside) }
        store.revealDockCommand = { [weak self] in
            guard let self else { return }
            self.dockOpenedByCommand = true; self.store.dockRevealed = true
            self.resize(expanded: self.store.expanded, animated: true)
        }
        store.dragBegan = { [weak self] in self?.beginDrag() }
        store.dragEnded = { [weak self] in self?.endDrag() }
        store.canDismissPanel = { [weak self] in self?.panel?.attachedSheet == nil }
        store.canHoverSwitch = { [weak self] in
            guard let self, let panel = self.panel else { return true }
            if self.openedByCommand { return false }
            if panel.attachedSheet != nil || self.store.capturePresented || self.store.recordingShortcut || self.store.receivingFiles { return false }
            if panel.isKeyWindow, let editor = panel.firstResponder as? NSTextView, editor.isEditable { return false }
            return true
        }
        store.filesDropped = { [weak self] in
            guard let self else { return }
            self.hoverTask?.cancel(); self.openedByCommand = false
            self.store.expanded = true; self.resize(expanded: true, animated: true)
            self.hover(self.containsMouse())
        }
        store.activatePanel = { [weak self] in self?.showPanel() }
        let view = PanelView().environmentObject(store).environmentObject(store.reminders)
        panel = PerchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.dismissFlyout = { [weak self] in self?.store.expanded = false; self?.store.editingWidgets = false }
        panel.title = demo ? "Perch Preview" : "Perch"
        panel.contentView = FileDropHostingView(rootView: view, store: store)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false; panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        dockPanel = PerchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        dockPanel.title = "Perch Dock"
        dockPanel.dismissFlyout = { [weak self] in
            self?.dockOpenedByCommand = false; self?.store.expanded = false; self?.store.editingWidgets = false
            self?.scheduleRetraction()
        }
        dockPanel.contentView = FileDropHostingView(rootView: DockRailContainer().environmentObject(store).environmentObject(store.reminders), store: store)
        dockPanel.isOpaque = false; dockPanel.backgroundColor = .clear; dockPanel.hasShadow = true
        dockPanel.level = .floating; dockPanel.hidesOnDeactivate = false
        dockPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        dockPanel.isReleasedWhenClosed = false; dockPanel.isFloatingPanel = true
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Perch")
        status.button?.imagePosition = .imageLeading
        status.button?.toolTip = "Perch · widgets and quick capture"
        status.button?.setAccessibilityLabel("Perch")
        let menu = NSMenu(); menu.delegate = self; status.menu = menu
        rebuildStatusMenu(menu)
        store.$now.sink { [weak self] date in self?.updateStatusTitle(at: date) }.store(in: &cancellables)
        store.$data.map { $0.preferences.theme }.removeDuplicates().dropFirst().sink { theme in
            NSApp.appearance = theme.appearance
        }.store(in: &cancellables)
        store.$expanded.removeDuplicates().sink { [weak self] expanded in
            DispatchQueue.main.async {
                guard self?.store.expanded == expanded else { return }
                if !expanded { self?.openedByCommand = false; self?.dockOpenedByCommand = false }
                self?.resize(expanded: expanded, animated: true)
            }
        }.store(in: &cancellables)
        store.$data.map { "\($0.preferences.dockEdge.rawValue):\($0.preferences.dockFraction):\($0.preferences.dockDisplayID ?? 0):\($0.preferences.dockVisible):\($0.preferences.widgets):\($0.notes.count):\($0.focus != nil)" }
            .removeDuplicates().dropFirst().sink { [weak self] _ in
                DispatchQueue.main.async { guard let self, !self.store.isDragging else { return }; self.resize(expanded: self.store.expanded, animated: true) }
            }.store(in: &cancellables)
        store.$section.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { guard let self else { return }; self.resize(expanded: self.store.expanded, animated: true) }
        }.store(in: &cancellables)
        store.$selectedNoteID.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { guard let self else { return }; self.resize(expanded: self.store.expanded, animated: true) }
        }.store(in: &cancellables)
        store.$widgetOffsets.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { guard let self, self.store.expanded else { return }; self.resize(expanded: true) }
        }.store(in: &cancellables)
        store.$data.map { $0.preferences.widgetShortcuts }.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.registerWidgetShortcuts() }
        }.store(in: &cancellables)
        store.$recordingShortcut.removeDuplicates().dropFirst().sink { [weak self] recording in
            DispatchQueue.main.async {
                guard let self else { return }
                if recording {
                    if let key = self.hotKey { UnregisterEventHotKey(key); self.hotKey = nil }
                    for key in self.widgetHotKeys.values { UnregisterEventHotKey(key) }
                    self.widgetHotKeys.removeAll()
                } else { self.registerCaptureShortcut(); self.registerWidgetShortcuts() }
            }
        }.store(in: &cancellables)
        Publishers.CombineLatest3(store.$undoLabel, store.$toast, store.$error)
            .map { "\($0 != nil):\($1 != nil):\($2 != nil)" }.removeDuplicates().dropFirst().sink { [weak self] _ in
                DispatchQueue.main.async { guard let self else { return }; self.resize(expanded: self.store.expanded, animated: true) }
            }.store(in: &cancellables)
        store.reminders.$error.map { $0 != nil }.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { guard let self else { return }; self.resize(expanded: self.store.expanded, animated: true) }
        }.store(in: &cancellables)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; self.resize(expanded: self.store.expanded) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: .NSSystemClockDidChange, object: nil)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.tick(); self?.store.reminders.refresh() }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(resignedActive), name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuOpened), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuClosed), name: NSMenu.didEndTrackingNotification, object: nil)
        setupEditMenu()
        registerShortcut()
        registerWidgetShortcuts()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismissOnOutsideClick() }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type != .keyDown { self.dismissOnOutsideClick(); return event }
            guard !self.store.recordingShortcut else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var modifiers: UInt32 = 0
            if flags.contains(.control) { modifiers |= UInt32(controlKey) }
            if flags.contains(.option) { modifiers |= UInt32(optionKey) }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if event.keyCode == kVK_Space && modifiers == UInt32(controlKey | optionKey) { self.quickCapture(); return nil }
            if let widget = DockWidget.allCases.first(where: { widget in
                guard let shortcut = self.store.data.preferences.widgetShortcuts[widget.rawValue] else { return false }
                return shortcut.keyCode == UInt32(event.keyCode) && shortcut.modifiers == modifiers
            }) {
                self.store.activateWidgetShortcut(widget); return nil
            }
            return event
        }
        store.expanded = false
        resize(expanded: false)
    }

    func resize(expanded: Bool, animated: Bool = false) {
        guard let panel else { return }
        let remembered = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == store.data.preferences.dockDisplayID }
        let screen = remembered ?? dockPanel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let vertical = store.data.preferences.dockEdge.isVertical
        let limit = max(114, min(vertical ? 640 : 820, (vertical ? screen.visibleFrame.height : screen.visibleFrame.width) - 16))
        if store.dockLengthLimit != limit { store.dockLengthLimit = limit }
        let layout = DockGeometry.layout(edge: store.data.preferences.dockEdge, fraction: store.data.preferences.dockFraction, visible: screen.visibleFrame,
            compactSize: store.dockSize, panelSize: store.preferredPanelSize, expanded: true, widgetOffset: store.hoveredWidgetOffset)
        func global(_ rect: CGRect) -> CGRect {
            CGRect(x: layout.window.minX + rect.minX, y: layout.window.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        let frame = global(layout.content)
        let fullDockFrame = global(layout.dock)
        if (expanded || store.isDragging || store.receivingFiles) && !store.dockRevealed { store.dockRevealed = true }
        let peekFrame = DockGeometry.peekFrame(full: fullDockFrame, edge: store.data.preferences.dockEdge, visible: screen.visibleFrame)
        // The transparent edge gap stays in the window's tracking area, so the
        // dock does not retract underneath a pointer resting at the screen edge.
        let revealedFrame = fullDockFrame.union(peekFrame)
        let dockFrame = store.dockRevealed ? revealedFrame : peekFrame
        let revealingDock = store.dockRevealed && (store.data.preferences.dockEdge.isVertical ? dockPanel.frame.width < revealedFrame.width : dockPanel.frame.height < revealedFrame.height)
        let movingDock = !dockPanel.frame.equalTo(dockFrame)
        store.panelHeight = frame.height; store.panelWidth = frame.width; store.pointerOffset = layout.pointerOffset
        animationGeneration += 1
        let generation = animationGeneration
        // Explicit Perch preference: the user requested this slide even while
        // macOS Reduce Motion is enabled. Other app motion still follows macOS.
        let shouldAnimate = animated && dockPanel.frame.width > 0 && store.data.preferences.smoothDockMotion
        if shouldAnimate {
            resizing = true
            if expanded && !panel.isVisible {
                var start = frame
                switch store.data.preferences.dockEdge {
                case .left: start.origin.x -= 8
                case .right: start.origin.x += 8
                case .top: start.origin.y += 8
                case .bottom: start.origin.y -= 8
                }
                panel.setFrame(start, display: true); panel.alphaValue = 0; panel.orderFrontRegardless()
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = movingDock ? (store.dockRevealed ? 0.34 : 0.30) : (expanded ? 0.26 : 0.18)
                context.timingFunction = movingDock ? CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1) : CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
                if movingDock && !self.store.isDragging { self.dockPanel.animator().setFrame(dockFrame, display: true) }
                if !panel.frame.equalTo(frame) { panel.animator().setFrame(frame, display: true) }
                let opacity: CGFloat = expanded ? 1 : 0
                if panel.alphaValue != opacity { panel.animator().alphaValue = opacity }
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self, self.animationGeneration == generation else { return }
                    self.resizing = false
                    if !self.store.expanded { self.panel.orderOut(nil) }
                    if self.store.expanded && !self.containsMouse() { self.hover(false) }
                    if revealingDock, !self.store.expanded, self.store.dockRevealed, self.store.hoveredWidget != nil, self.containsMouse() { self.hover(true) }
                    self.scheduleRetraction()
                }
            }
        } else {
            dockPanel.setFrame(dockFrame, display: true)
            panel.setFrame(frame, display: true); panel.alphaValue = expanded ? 1 : 0; resizing = false
            if expanded { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        }
        if store.data.preferences.dockVisible { dockPanel.orderFrontRegardless() } else { dockPanel.orderOut(nil) }
        if expanded { panel.orderFrontRegardless() }
        if !shouldAnimate { scheduleRetraction() }
    }
    private func dockHover(_ inside: Bool) {
        dockOpenedByCommand = false
        if inside {
            retractTask?.cancel()
            if !store.dockRevealed {
                store.dockRevealed = true
                resize(expanded: store.expanded, animated: true)
            }
        } else {
            hover(false, pointerEvent: true)
            scheduleRetraction()
        }
    }
    private func scheduleRetraction() {
        retractTask?.cancel()
        guard store.dockRevealed, !store.expanded, !dockOpenedByCommand else { return }
        retractTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, !self.dockOpenedByCommand, !self.containsMouse(), !self.store.expanded, !self.store.isDragging,
                  !self.store.receivingFiles, !self.store.editingWidgets, !self.store.recordingShortcut,
                  !self.store.capturePresented, self.store.openDialogCount == 0, !self.menuTracking else { return }
            self.store.dockRevealed = false
            self.resize(expanded: false, animated: true)
        }
    }
    private func containsMouse() -> Bool {
        let point = NSEvent.mouseLocation
        return (dockPanel.isVisible && dockPanel.frame.insetBy(dx: -6, dy: -6).contains(point)) || (store.expanded && panel.frame.insetBy(dx: -6, dy: -6).contains(point))
    }
    private func hover(_ inside: Bool, pointerEvent: Bool = false) {
        hoverTask?.cancel()
        guard !store.isDragging, !resizing, Date().timeIntervalSince(lastDrag) > 0.7 else { return }
        if pointerEvent && (!inside || panel.frame.contains(NSEvent.mouseLocation)) { openedByCommand = false }
        hoverTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(inside ? 140 : 320)) } catch { return }
            guard let self, !self.store.isDragging, !self.resizing else { return }
            if inside {
                guard self.containsMouse(), !self.store.expanded else { return }
                self.store.expanded = true
            } else {
                guard self.store.expanded, !self.containsMouse(), !self.menuTracking, !self.store.editingWidgets, !self.openedByCommand, !self.store.recordingShortcut, !self.store.receivingFiles,
                      self.panel.attachedSheet == nil, NSApp.modalWindow == nil, self.store.openDialogCount == 0,
                      !self.store.capturePresented else { return }
                if self.panel.isKeyWindow, let editor = self.panel.firstResponder as? NSTextView, editor.isEditable { return }
                if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared()?.isVisible == true { return }
                self.store.expanded = false
            }
        }
    }
    private func dismissOnOutsideClick() {
        if !containsMouse() { dockOpenedByCommand = false; scheduleRetraction() }
        guard store.expanded, !containsMouse(), panel.attachedSheet == nil, !store.capturePresented,
              !store.receivingFiles, !store.isDragging, store.openDialogCount == 0, !menuTracking else { return }
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared()?.isVisible == true { return }
        hoverTask?.cancel(); openedByCommand = false
        store.expanded = false; store.editingWidgets = false
    }
    private func beginDrag() { hoverTask?.cancel(); retractTask?.cancel(); store.dockRevealed = true; store.isDragging = true }
    private func endDrag() {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? dockPanel.screen else { store.isDragging = false; return }
        let edge = DockGeometry.nearestEdge(to: point, in: screen.visibleFrame)
        store.data.preferences.dockEdge = edge
        let anchor = edge.isVertical ? CGPoint(x: point.x, y: point.y - store.dockSize.height / 2 + 13) : CGPoint(x: point.x + store.dockSize.width / 2 - 13, y: point.y)
        store.data.preferences.dockFraction = DockGeometry.fraction(for: anchor, edge: edge, visible: screen.visibleFrame, compactSize: store.dockSize)
        store.data.preferences.dockDisplayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        store.expanded = false; store.isDragging = false; lastDrag = Date()
        resize(expanded: false, animated: true)
    }
    @objc func showPanel() {
        hoverTask?.cancel(); openedByCommand = true; store.expanded = true
        resize(expanded: true, animated: true)
        NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
    }
    @objc func quickCapture() { showPanel(); store.capturePresented = true }
    @objc func showSettings() { showPanel(); store.section = .settings }
    @objc func becameActive() { store?.tick(); store?.reminders.refresh() }
    @objc private func clockChanged() { store?.tick() }
    @objc func resignedActive() { if panel != nil { hover(containsMouse()) } }
    @objc func menuOpened() { menuTracking = true; hoverTask?.cancel() }
    @objc func menuClosed() { menuTracking = false; if panel != nil { hover(containsMouse()) } }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let store, panel?.attachedSheet != nil || store.capturePresented || store.openDialogCount > 0 {
            let alert = NSAlert()
            alert.messageText = "Finish the open editor first"
            alert.informativeText = "Save or cancel the open editor or file dialog, then quit or update Perch again."
            alert.addButton(withTitle: "Keep Perch open"); alert.runModal()
            return .terminateCancel
        }
        guard store?.flush() != false else {
            let alert = NSAlert()
            alert.messageText = "Your latest changes haven’t been saved"
            alert.informativeText = store.error ?? "Check available disk space and folder access, then quit again."
            alert.addButton(withTitle: "Keep Perch open"); alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    private func registerShortcut() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context -> OSStatus in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let app = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            var identifier = EventHotKeyID()
            guard let event, GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr else { return OSStatus(eventNotHandledErr) }
            let id = identifier.id
            Task { @MainActor in
                guard !app.store.recordingShortcut else { return }
                if id == 1 { app.quickCapture() }
                else if id >= 100, Int(id - 100) < DockWidget.allCases.count {
                    let widget = DockWidget.allCases[Int(id - 100)]
                    app.store.activateWidgetShortcut(widget)
                }
            }
            return noErr
        }, 1, &eventSpec, pointer, &eventHandler)
        if status != noErr { store.error = "Keyboard shortcuts are unavailable. Use the Perch menu bar." }
        registerCaptureShortcut()
    }
    private func registerCaptureShortcut() {
        guard !store.recordingShortcut else { return }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        let identifier = EventHotKeyID(signature: 0x50524348, id: 1)
        let registered = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), identifier, GetApplicationEventTarget(), 0, &hotKey)
        if registered != noErr { store.error = "Control–Option–Space is unavailable. Use the Perch menu bar → Quick capture, or free this shortcut in the other app." }
    }
    private func registerWidgetShortcuts() {
        guard !store.recordingShortcut else { return }
        for key in widgetHotKeys.values { UnregisterEventHotKey(key) }
        widgetHotKeys.removeAll(); store.shortcutErrors = [:]
        for (index, widget) in DockWidget.allCases.enumerated() {
            guard let shortcut = store.data.preferences.widgetShortcuts[widget.rawValue] else { continue }
            var reference: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: 0x50524348, id: UInt32(100 + index))
            let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier, GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference { widgetHotKeys[widget.rawValue] = reference }
            else { store.shortcutErrors[widget.rawValue] = "Unavailable — try another shortcut." }
        }
    }
    func menuWillOpen(_ menu: NSMenu) { rebuildStatusMenu(menu) }
    private func rebuildStatusMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        func item(_ title: String, _ action: Selector) {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
        }
        item(store.data.preferences.dockVisible ? "Hide dock" : "Show dock", #selector(toggleDockVisibility))
        item("Quick capture   ⌃⌥Space", #selector(quickCapture))
        menu.addItem(.separator())
        for widget in DockWidget.allCases {
            let shortcut = store.data.preferences.widgetShortcuts[widget.rawValue]?.display
            let item = menu.addItem(withTitle: widget.title + (shortcut.map { "   " + $0 } ?? ""), action: #selector(openWidgetFromMenu(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = widget.rawValue
            item.image = NSImage(systemSymbolName: widget.section.symbol, accessibilityDescription: widget.title)
        }
        if let focus = store.data.focus {
            menu.addItem(.separator())
            let summary = menu.addItem(withTitle: "\(timeString(focus.remaining(at: Date()))) · \(focus.title)", action: nil, keyEquivalent: "")
            summary.isEnabled = false
            item(focus.isRunning ? "Pause focus" : "Resume focus", #selector(toggleFocusFromMenu))
        }
        menu.addItem(.separator())
        item("Edit widgets & shortcuts…", #selector(showWidgets))
        item("Settings…", #selector(showSettings))
        menu.addItem(.separator())
        item("Quit Perch", #selector(quit))
    }
    private func updateStatusTitle(at date: Date = Date()) {
        guard status != nil else { return }
        status.button?.title = store.data.focus.map { " " + timeString($0.remaining(at: date)) } ?? ""
        status.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    }
    @objc private func toggleDockVisibility() {
        store.data.preferences.dockVisible.toggle(); store.expanded = false; store.editingWidgets = false
        resize(expanded: false, animated: false)
    }
    @objc private func openWidgetFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let widget = DockWidget(rawValue: raw) else { return }
        store.section = widget.section; store.editingWidgets = false; showPanel()
    }
    @objc private func showWidgets() { store.section = .widgets; store.editingWidgets = true; showPanel() }
    @objc private func toggleFocusFromMenu() { store.toggleFocus(); updateStatusTitle() }
    private func setupEditMenu() {
        let main = NSMenu()
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit Perch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let edit = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editItem.submenu = edit; main.addItem(editItem)
        NSApp.mainMenu = main
    }
}

@main struct PerchApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
