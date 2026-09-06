import AppKit
import CoreImage
import UniformTypeIdentifiers
import PerchCore

extension AppStore {
    var play: PlayData {
        get { data.play ?? PlayData() }
        set { data.play = newValue }
    }
    func startRelax() {
        guard breathingSession == nil else { return }
        let date = Date(); now = date
        breathingSession = BreathingSession(minutes: play.relax.minutes, now: date, mode: play.relax.mode)
        if !demo, let session = breathingSession { relaxAudio.update(session: session, settings: play.relax, at: date) }
    }
    func keepColor(_ source: String) {
        do {
            let color = try ColorSwatch(hex: source)
            play.swatches.removeAll { $0.hex == color.hex }
            play.swatches.insert(color, at: 0); play.swatches = Array(play.swatches.prefix(24))
        } catch { self.error = error.localizedDescription }
    }
    func sampleColor() {
        guard !demo else { showToast("Preview: screen color sampling is disabled"); return }
        openDialogCount += 1; expanded = false
        let sampler = NSColorSampler(); colorSampler = sampler
        sampler.show { [weak self] color in
            Task { @MainActor in
            guard let self else { return }
            self.openDialogCount = max(0, self.openDialogCount - 1); self.colorSampler = nil
            if let rgb = color?.usingColorSpace(.sRGB) {
                self.keepColor(String(format: "#%02X%02X%02X", Int(round(rgb.redComponent * 255)), Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255))))
            }
            self.section = .colors; self.expanded = true; self.activatePanel?()
            }
        }
    }
    func removeColor(_ item: ColorSwatch) {
        let index = play.swatches.firstIndex(where: { $0.id == item.id }) ?? 0
        play.swatches.removeAll { $0.id == item.id }
        offerUndo("Color removed") { [weak self] in
            guard let self, !self.play.swatches.contains(where: { $0.hex == item.hex }) else { return }
            self.play.swatches.insert(item, at: min(index, self.play.swatches.count))
        }
    }
    func addStroke(_ stroke: DoodleStroke) {
        guard !stroke.points.isEmpty else { return }
        guard play.strokes.reduce(0, { $0 + $1.points.count }) + stroke.points.count <= 6000 else { error = PlayError.drawingFull.localizedDescription; return }
        play.strokes.append(stroke)
    }
    func savePNG(_ data: Data, suggestedName: String) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = suggestedName
        openDialogCount += 1
        panel.begin { [weak self] response in
            guard let self else { return }; self.openDialogCount = max(0, self.openDialogCount - 1)
            guard response == .OK, let url = panel.url else { return }
            do { try data.write(to: url, options: .atomic); self.showToast("Image saved") }
            catch { self.error = "The image couldn’t be saved. \(error.localizedDescription)" }
        }
    }
    func copyPNG(_ data: Data) {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setData(data, forType: .png) else { error = "The image couldn’t be copied. Try again."; return }
        showToast("Image copied")
    }
}

enum QRRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    static func render(_ text: String) throws -> CGImage {
        guard !text.isEmpty else { throw PlayError.qrUnavailable }
        guard text.utf8.count <= 1500 else { throw PlayError.qrTooLong }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { throw PlayError.qrUnavailable }
        filter.setValue(Data(text.utf8), forKey: "inputMessage"); filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { throw PlayError.qrUnavailable }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let image = context.createCGImage(scaled, from: scaled.extent) else { throw PlayError.qrUnavailable }; return image
    }
    static func png(_ text: String) throws -> Data {
        let image = try render(text)
        let border = 32
        let width = image.width + border * 2, height = image.height + border * 2
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PlayError.qrUnavailable }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none; context.draw(image, in: CGRect(x: border, y: border, width: image.width, height: image.height))
        guard let final = context.makeImage(), let data = NSBitmapImageRep(cgImage: final).representation(using: .png, properties: [:]) else { throw PlayError.qrUnavailable }; return data
    }
}

@MainActor enum DoodleRenderer {
    static func png(_ strokes: [DoodleStroke]) -> Data? {
        let size = NSSize(width: 640, height: 400)
        let image = NSImage(size: size); image.lockFocus()
        NSColor.white.setFill(); NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            let c = (try? ColorCode.components(stroke.hex)) ?? (red: 7, green: 95, blue: 183)
            let color = NSColor(srgbRed: Double(c.red) / 255, green: Double(c.green) / 255, blue: Double(c.blue) / 255, alpha: 1)
            color.setStroke(); color.setFill()
            let path = NSBezierPath(); path.lineWidth = 5; path.lineCapStyle = .round; path.lineJoinStyle = .round
            func point(_ p: DrawingPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height) }
            if stroke.points.count == 1 { NSBezierPath(ovalIn: CGRect(x: point(first).x - 2.5, y: point(first).y - 2.5, width: 5, height: 5)).fill() }
            else { path.move(to: point(first)); for p in stroke.points.dropFirst() { path.line(to: point(p)) }; path.stroke() }
        }
        image.unlockFocus()
        return image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?.representation(using: .png, properties: [:])
    }
}
