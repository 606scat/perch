import AppKit
import Testing
@testable import Perch

@Test @MainActor func nativeRailMaterialKeepsTransparentCornersAfterResizing() throws {
    let material = PerchMaterialView(frame: CGRect(x: 0, y: 0, width: 64, height: 414))
    material.roundedRail = true
    for size in [CGSize(width: 64, height: 414), CGSize(width: 420, height: 66), CGSize(width: 64, height: 640)] {
        material.setFrameSize(size)
        material.layout()
        let mask = try #require(material.maskImage)
        var rect = CGRect(origin: .zero, size: size)
        let image = try #require(mask.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        let pixels = NSBitmapImageRep(cgImage: image)
        #expect(mask.size == size)
        // AppKit may rasterize the resolution-independent mask at Retina scale.
        #expect(pixels.pixelsWide >= Int(size.width))
        #expect(CGFloat(pixels.pixelsWide) * size.height == CGFloat(pixels.pixelsHigh) * size.width)
        for x in [0, pixels.pixelsWide - 1] {
            for y in [0, pixels.pixelsHigh - 1] {
                #expect(try #require(pixels.colorAt(x: x, y: y)).alphaComponent < 0.01)
            }
        }
        #expect(try #require(pixels.colorAt(x: pixels.pixelsWide / 2, y: 0)).alphaComponent > 0.99)
        #expect(try #require(pixels.colorAt(x: pixels.pixelsWide / 2, y: pixels.pixelsHigh / 2)).alphaComponent > 0.99)
        // Ordinary layout passes keep the same mask instead of reallocating it.
        material.layout()
        #expect(material.maskImage === mask)
    }
    material.roundedRail = false
    #expect(material.maskImage == nil)
}
