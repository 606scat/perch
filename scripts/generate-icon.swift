import AppKit
import Foundation

// Native SF Symbols icon, composed here; no third-party bitmap source.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let factor = CGFloat(pixels) / 1024
    let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
    let body = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 198, yRadius: 198)
    NSColor(calibratedWhite: 0.09, alpha: 1).setFill(); body.fill()
    NSColor(calibratedWhite: 0.28, alpha: 1).setStroke(); body.lineWidth = 3; body.stroke()
    let symbol = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(paletteColors: [NSColor(calibratedRed: 0.28, green: 0.66, blue: 1, alpha: 1)]))!
    symbol.draw(in: NSRect(x: 255, y: 267, width: 514, height: 514))
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
}
