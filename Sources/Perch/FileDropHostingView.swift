import AppKit
import SwiftUI
import PerchCore

@MainActor final class FileDropHostingView<Content: View>: NSHostingView<Content> {
    weak var store: AppStore?
    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }
    convenience init(rootView: Content, store: AppStore) {
        self.init(rootView: rootView); self.store = store
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !FileDropDecoder.urls(from: sender.draggingPasteboard).isEmpty, store?.storageLocked == false else { return [] }
        store?.receivingFiles = true
        store?.section = .tray; store?.expanded = true
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        store?.receivingFiles = false; store?.hoverChanged?(false)
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { store?.storageLocked == false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = FileDropDecoder.urls(from: sender.draggingPasteboard)
        store?.receivingFiles = false
        guard !urls.isEmpty, let store, !store.storageLocked else { return false }
        store.addFiles(urls); store.filesDropped?()
        return true
    }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { store?.receivingFiles = false }
}
