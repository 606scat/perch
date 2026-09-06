import SwiftUI
import PerchCore

/// Shared, resolution-independent artwork drawn on a 24-point grid.
struct WidgetGlyph: View {
    var widget: DockWidget
    var body: some View {
        WidgetGlyphPath(widget: widget)
            .stroke(style: StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

private struct WidgetGlyphPath: Shape {
    var widget: DockWidget
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func line(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            p.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
        }
        switch widget {
        case .focus:
            line([(13.5, 2.5), (5.5, 13), (11, 13), (10.5, 21.5), (18.5, 10.5), (13, 10.5), (13.5, 2.5)])
        case .today:
            p.addRoundedRect(in: CGRect(x: 3, y: 4, width: 18, height: 17), cornerSize: CGSize(width: 4, height: 4))
            line([(7.5, 2.5), (7.5, 6)])
            line([(16.5, 2.5), (16.5, 6)])
            line([(3.5, 9), (20.5, 9)])
            line([(8, 14.5), (10.5, 17), (16, 12)])
        case .notes:
            p.addRoundedRect(in: CGRect(x: 4, y: 2.5, width: 16, height: 19), cornerSize: CGSize(width: 3, height: 3))
            line([(8, 8), (16, 8)])
            line([(8, 12), (16, 12)])
            line([(8, 16), (12.5, 16)])
        case .tray:
            line([(3, 13), (6.5, 7.5), (8, 7.5)])
            line([(16, 7.5), (17.5, 7.5), (21, 13)])
            p.move(to: CGPoint(x: 3, y: 13))
            p.addLine(to: CGPoint(x: 8, y: 13))
            p.addCurve(to: CGPoint(x: 16, y: 13), control1: CGPoint(x: 8, y: 18), control2: CGPoint(x: 16, y: 18))
            p.addLine(to: CGPoint(x: 21, y: 13))
            p.addLine(to: CGPoint(x: 21, y: 18.5))
            p.addQuadCurve(to: CGPoint(x: 18.5, y: 21), control: CGPoint(x: 21, y: 21))
            p.addLine(to: CGPoint(x: 5.5, y: 21))
            p.addQuadCurve(to: CGPoint(x: 3, y: 18.5), control: CGPoint(x: 3, y: 21))
            p.closeSubpath()
            line([(12, 2.5), (12, 11)])
            line([(9, 8), (12, 11), (15, 8)])
        case .snippets:
            for x: CGFloat in [3.5, 13.5] {
                p.addRoundedRect(in: CGRect(x: x, y: 5, width: 7, height: 8), cornerSize: CGSize(width: 2, height: 2))
                p.move(to: CGPoint(x: x + 7, y: 11))
                p.addCurve(to: CGPoint(x: x + 1.5, y: 19), control1: CGPoint(x: x + 7, y: 16), control2: CGPoint(x: x + 5, y: 18))
            }
        case .projects:
            p.move(to: CGPoint(x: 3, y: 8))
            p.addLine(to: CGPoint(x: 3, y: 6))
            p.addQuadCurve(to: CGPoint(x: 5, y: 4), control: CGPoint(x: 3, y: 4))
            line([(5, 4), (10, 4), (12, 7), (19, 7)])
            p.addQuadCurve(to: CGPoint(x: 21, y: 9), control: CGPoint(x: 21, y: 7))
            p.addRoundedRect(in: CGRect(x: 3, y: 9, width: 18, height: 11), cornerSize: CGSize(width: 2.5, height: 2.5))
        case .clipboard:
            p.addRoundedRect(in: CGRect(x: 5, y: 4, width: 14, height: 17), cornerSize: CGSize(width: 2, height: 2))
            p.addRoundedRect(in: CGRect(x: 8, y: 2, width: 8, height: 5), cornerSize: CGSize(width: 1.5, height: 1.5))
            line([(8, 12), (16, 12)]); line([(8, 16), (14, 16)])
        case .calculator:
            p.addRoundedRect(in: CGRect(x: 4, y: 2, width: 16, height: 20), cornerSize: CGSize(width: 3, height: 3))
            line([(8, 7), (16, 7)]); line([(8, 12), (10, 12)]); line([(9, 11), (9, 13)])
            line([(14, 12), (16, 12)]); line([(8, 17), (10, 19)]); line([(8, 19), (10, 17)])
            line([(14, 17), (16, 17)]); line([(14, 19), (16, 19)])
        case .converter:
            line([(4, 7), (20, 7)]); line([(16, 3), (20, 7), (16, 11)])
            line([(20, 17), (4, 17)]); line([(8, 13), (4, 17), (8, 21)])
        case .clocks:
            p.addEllipse(in: CGRect(x: 2.5, y: 2.5, width: 19, height: 19))
            p.addEllipse(in: CGRect(x: 7, y: 2.5, width: 10, height: 19))
            line([(3, 12), (21, 12)])
        case .countdowns:
            p.addRoundedRect(in: CGRect(x: 3, y: 4, width: 18, height: 17), cornerSize: CGSize(width: 3, height: 3))
            line([(7, 2), (7, 6)]); line([(17, 2), (17, 6)]); line([(3, 9), (21, 9)])
            line([(12, 12), (12, 17), (15, 17)])
        case .habits:
            p.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
            line([(7.5, 12), (10.5, 15), (16.5, 9)])
        case .breathing:
            for (y, width): (CGFloat, CGFloat) in [(6, 15), (12, 19), (18, 12)] {
                p.move(to: CGPoint(x: 3, y: y))
                p.addCurve(to: CGPoint(x: width, y: y), control1: CGPoint(x: 7, y: y - 4), control2: CGPoint(x: 11, y: y + 4))
            }
        case .awake:
            p.addRoundedRect(in: CGRect(x: 3, y: 8, width: 13, height: 11), cornerSize: CGSize(width: 3, height: 3))
            p.move(to: CGPoint(x: 16, y: 9)); p.addCurve(to: CGPoint(x: 16, y: 16), control1: CGPoint(x: 23, y: 7), control2: CGPoint(x: 23, y: 18))
            line([(6, 4), (6, 2)]); line([(11, 4), (11, 2)]); line([(2, 22), (19, 22)])
        }
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24).translatedBy(x: rect.minX, y: rect.minY))
    }
}
