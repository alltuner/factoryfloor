// ABOUTME: The Poblenou skyline as a SwiftUI shape.
// ABOUTME: Rendered from the alltuner.com SVG path data.

import SwiftUI

struct PoblenouSkyline: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 1200
        let sy = rect.height / 260
        var p = Path()

        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        p.move(to: pt(20, 220))
        p.addLine(to: pt(80, 220))
        p.addLine(to: pt(80, 200))
        p.addLine(to: pt(120, 200))
        p.addLine(to: pt(120, 220))
        p.addLine(to: pt(170, 220))
        p.addLine(to: pt(170, 195))
        p.addLine(to: pt(220, 195))
        p.addLine(to: pt(220, 220))
        p.addLine(to: pt(240, 220))
        p.addLine(to: pt(240, 130))
        p.addLine(to: pt(256, 130))
        p.addLine(to: pt(256, 220))
        p.addLine(to: pt(280, 220))
        p.addLine(to: pt(280, 205))
        p.addLine(to: pt(320, 205))
        p.addLine(to: pt(320, 220))
        p.addLine(to: pt(340, 220))
        p.addLine(to: pt(340, 200))
        p.addLine(to: pt(360, 190))
        p.addLine(to: pt(380, 200))
        p.addLine(to: pt(400, 190))
        p.addLine(to: pt(420, 200))
        p.addLine(to: pt(440, 190))
        p.addLine(to: pt(460, 200))
        p.addLine(to: pt(480, 200))
        p.addLine(to: pt(480, 220))
        p.addLine(to: pt(520, 220))
        p.addLine(to: pt(520, 140))
        p.addLine(to: pt(538, 140))
        p.addLine(to: pt(538, 220))
        p.addLine(to: pt(560, 220))
        p.addLine(to: pt(560, 190))
        p.addLine(to: pt(630, 190))
        p.addLine(to: pt(630, 220))
        p.addLine(to: pt(660, 220))
        p.addLine(to: pt(660, 115))
        p.addLine(to: pt(676, 115))
        p.addLine(to: pt(676, 220))
        p.addLine(to: pt(700, 220))
        p.addLine(to: pt(700, 200))
        p.addLine(to: pt(735, 200))
        p.addLine(to: pt(735, 180))
        p.addLine(to: pt(770, 180))
        p.addLine(to: pt(770, 220))
        p.addLine(to: pt(800, 220))
        p.addLine(to: pt(800, 150))
        p.addLine(to: pt(816, 150))
        p.addLine(to: pt(816, 220))
        p.addLine(to: pt(882, 220))
        // Torre Agbar curve
        p.addCurve(to: pt(948, 220),
                   control1: pt(882, 100),
                   control2: pt(948, 100))
        p.addLine(to: pt(1040, 220))
        p.addLine(to: pt(1040, 205))
        p.addLine(to: pt(1080, 205))
        p.addLine(to: pt(1080, 220))
        p.addLine(to: pt(1120, 220))
        p.addLine(to: pt(1120, 190))
        p.addLine(to: pt(1160, 190))
        p.addLine(to: pt(1160, 220))
        p.addLine(to: pt(1180, 220))

        return p
    }
}

struct PoblenouSkylineView: View {
    var body: some View {
        PoblenouSkyline()
            .stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .aspectRatio(1200/260, contentMode: .fit)
    }
}
