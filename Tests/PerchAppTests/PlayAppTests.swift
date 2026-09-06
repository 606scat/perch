import Testing
import AppKit
import AVFoundation
import Vision
import Combine
import PerchCore
@testable import Perch

@Test @MainActor func backgroundClockNotificationPublishesOnMainThread() async {
    let delegate = AppDelegate(); let store = AppStore(demo: true); delegate.store = store
    store.now = Date.distantPast
    let stream = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let subscription = store.$now.dropFirst().sink { _ in stream.continuation.yield(Thread.isMainThread) }
    await Task.detached { delegate.clockChanged() }.value
    for await isMain in stream.stream { #expect(isMain); break }
    #expect(store.now > Date.distantPast)
    subscription.cancel(); stream.continuation.finish()
}

@Test func generatedQRDecodesToExactUnicodePayloadAndRejectsOversize() throws {
    let payload = "https://example.com/?message=こんにちは"
    let data = try QRRenderer.png(payload)
    let request = VNDetectBarcodesRequest(); request.symbologies = [.qr]
    try VNImageRequestHandler(data: data).perform([request])
    #expect(request.results?.first?.payloadStringValue == payload)
    #expect(throws: (any Error).self) { try QRRenderer.png(String(repeating: "🙂", count: 400)) }
    #expect(throws: (any Error).self) { try QRRenderer.png("") }
}
@Test @MainActor func drawingsAndNewWidgetStateRoundTripWithoutDiscardingEdits() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("data.json")
    let store = AppStore(dataURLOverride: url, connectSystemServices: false)
    store.data.preferences.interactionSounds = false
    store.keepColor("#a0f"); store.keepColor("#AA00FF"); #expect(store.play.swatches.count == 1)
    let swatch = try #require(store.play.swatches.first); store.removeColor(swatch); store.undo(); #expect(store.play.swatches == [swatch])
    let stroke = DoodleStroke(points: [DrawingPoint(x: -1, y: .infinity), DrawingPoint(x: 0.5, y: 0.5), DrawingPoint(x: 1, y: 1)], hex: "#09f")
    store.addStroke(stroke)
    let png = try #require(DoodleRenderer.png(store.play.strokes)); let image = try #require(NSBitmapImageRep(data: png))
    #expect(image.pixelsWide >= 640 && image.pixelsHigh >= 400)
    store.play.qrText = "https://example.com"; store.play.textInput = "Exact source\n"; store.play.decisionOptions = "tea\ncoffee"
    store.play.relax.sound = .ocean; store.play.relax.minutes = 5
    #expect(store.flush())
    let restored = AppStore(dataURLOverride: url, connectSystemServices: false)
    #expect(restored.play == store.play)
    #expect(stroke.points.first == DrawingPoint(x: 0, y: 0))
}
@Test @MainActor func updateGateSavesPendingChangesAndRejectsEditorsOrLockedStorage() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppStore(dataURLOverride: root.appendingPathComponent("Perch/data.json"), connectSystemServices: false)
    store.data.noteDraftDetail = "Unsaved typing"
    store.capturePresented = true
    #expect(throws: (any Error).self) { try store.prepareForUpdate() }
    store.capturePresented = false; store.canDismissPanel = { false }
    #expect(throws: (any Error).self) { try store.prepareForUpdate() }
    store.canDismissPanel = { true }; store.storageLocked = true
    #expect(throws: (any Error).self) { try store.prepareForUpdate() }
    store.storageLocked = false
    let backup = try store.prepareForUpdate()
    #expect(try Persistence.load(from: backup).noteDraftDetail == "Unsaved typing")
}
@Test func allAmbientTracksDecodeLocallyWithExpectedDuration() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    for sound in AmbientSound.allCases {
        let audio = try AVAudioFile(forReading: root.appendingPathComponent("Resources/Ambient/\(sound.rawValue).wav"))
        #expect(audio.processingFormat.channelCount == 1)
        #expect(Double(audio.length) / audio.processingFormat.sampleRate == 16)
    }
}
@Test @MainActor func completedFocusGrowsGardenExactlyOnceAndNewWidgetsFitEveryEdge() {
    let store = AppStore(demo: true); let end = store.data.focus!.endsAt!
    let before = store.play.garden.points; store.tick(at: end.addingTimeInterval(1))
    let after = store.play.garden.points; store.tick(at: end.addingTimeInterval(2))
    #expect(after > before && store.play.garden.points == after)
    #expect(Set(DockWidget.libraryOrder) == Set(DockWidget.allCases) && DockWidget.libraryOrder.count == 20)
    store.data.preferences.widgets = DockWidget.libraryOrder; store.dockLengthLimit = 510
    for edge in DockEdge.allCases {
        store.data.preferences.dockEdge = edge
        #expect((edge.isVertical ? store.dockSize.height : store.dockSize.width) == 510)
    }
}
