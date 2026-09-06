import AppKit
import Foundation

// Original Perch vector mark. No SF Symbols or third-party artwork in the icon.
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
    let flip = NSAffineTransform(); flip.translateX(by: 0, yBy: 1024); flip.scaleX(by: 1, yBy: -1); flip.concat()
    let bird = NSBezierPath()
    bird.move(to: .init(x: 263, y: 603))
    bird.curve(to: .init(x: 488, y: 421), controlPoint1: .init(x: 277, y: 477), controlPoint2: .init(x: 378, y: 394))
    bird.curve(to: .init(x: 665, y: 298), controlPoint1: .init(x: 494, y: 303), controlPoint2: .init(x: 604, y: 264))
    bird.curve(to: .init(x: 727, y: 407), controlPoint1: .init(x: 709, y: 319), controlPoint2: .init(x: 734, y: 363))
    bird.line(to: .init(x: 804, y: 435)); bird.line(to: .init(x: 723, y: 462))
    bird.curve(to: .init(x: 477, y: 638), controlPoint1: .init(x: 696, y: 566), controlPoint2: .init(x: 600, y: 635))
    bird.line(to: .init(x: 392, y: 695)); bird.line(to: .init(x: 403, y: 627)); bird.line(to: .init(x: 281, y: 664)); bird.close()
    NSColor(calibratedRed: 0.28, green: 0.66, blue: 1, alpha: 1).setFill(); bird.fill()
    let wing = NSBezierPath(); wing.move(to: .init(x: 346, y: 559))
    wing.curve(to: .init(x: 579, y: 477), controlPoint1: .init(x: 412, y: 462), controlPoint2: .init(x: 514, y: 449))
    wing.curve(to: .init(x: 346, y: 559), controlPoint1: .init(x: 534, y: 568), controlPoint2: .init(x: 437, y: 598)); wing.close()
    NSColor(calibratedRed: 0.14, green: 0.44, blue: 0.77, alpha: 1).setFill(); wing.fill()
    NSColor(calibratedWhite: 0.09, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 643, y: 357, width: 24, height: 24)).fill()
    let perch = NSBezierPath(roundedRect: NSRect(x: 300, y: 731, width: 420, height: 16), xRadius: 8, yRadius: 8)
    NSColor(calibratedWhite: 0.45, alpha: 1).setFill(); perch.fill()
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
}
