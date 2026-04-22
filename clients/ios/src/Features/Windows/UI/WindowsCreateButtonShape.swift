import SwiftUI

struct WindowsCreateButtonShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let mid = rect.midY
            let edge = rect.maxX

            p.move(to: CGPoint(x: edge, y: 0))
            p.addCurve(
                to: CGPoint(x: 0, y: mid),
                control1: CGPoint(x: edge, y: mid * 0.82),
                control2: CGPoint(x: 0, y: mid * 0.72)
            )
            p.addCurve(
                to: CGPoint(x: edge, y: rect.maxY),
                control1: CGPoint(x: 0, y: mid * 1.28),
                control2: CGPoint(x: edge, y: mid * 1.18)
            )
            p.closeSubpath()
        }
    }
}
