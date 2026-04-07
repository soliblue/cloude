import SwiftUI

extension WhiteboardSheet {
    static let roughness: Double = 1.0

    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    private func makeRNG(for rect: CGRect, pass: Int) -> SeededRNG {
        let seed = UInt64(abs(rect.origin.x * 1000 + rect.origin.y * 7919 + rect.width * 3571 + rect.height * 2399 + Double(pass) * 9973))
        return SeededRNG(seed: seed == 0 ? 1 : seed)
    }

    private func seededJitter(_ rng: inout SeededRNG, magnitude: Double) -> Double {
        let raw = Double(rng.next() % 10000) / 10000.0
        return (raw - 0.5) * 2.0 * magnitude
    }

    func sketchyRoundedRect(in rect: CGRect, cornerRadius: Double) -> Path {
        let cr = min(cornerRadius, min(rect.width, rect.height) / 2)
        let size = max(rect.width, rect.height)
        let jitterAmt = size * 0.012
        var combined = Path()

        for pass in 0..<2 {
            var rng = makeRNG(for: rect, pass: pass)
            let passOffset = pass == 0 ? jitterAmt * 0.3 : -jitterAmt * 0.3
            var path = Path()

            let corners = [
                (CGPoint(x: rect.minX + cr, y: rect.minY), CGPoint(x: rect.maxX - cr, y: rect.minY)),
                (CGPoint(x: rect.maxX, y: rect.minY + cr), CGPoint(x: rect.maxX, y: rect.maxY - cr)),
                (CGPoint(x: rect.maxX - cr, y: rect.maxY), CGPoint(x: rect.minX + cr, y: rect.maxY)),
                (CGPoint(x: rect.minX, y: rect.maxY - cr), CGPoint(x: rect.minX, y: rect.minY + cr)),
            ]

            let start = CGPoint(x: corners[0].0.x + seededJitter(&rng, magnitude: jitterAmt) + passOffset,
                                y: corners[0].0.y + seededJitter(&rng, magnitude: jitterAmt) + passOffset)
            path.move(to: start)

            for (i, (_, end)) in corners.enumerated() {
                let je = CGPoint(x: end.x + seededJitter(&rng, magnitude: jitterAmt) + passOffset,
                                 y: end.y + seededJitter(&rng, magnitude: jitterAmt) + passOffset)
                let dx = je.x - (path.currentPoint?.x ?? start.x)
                let dy = je.y - (path.currentPoint?.y ?? start.y)
                let mid1 = CGPoint(
                    x: (path.currentPoint?.x ?? start.x) + dx * 0.33 + seededJitter(&rng, magnitude: jitterAmt * 0.7),
                    y: (path.currentPoint?.y ?? start.y) + dy * 0.33 + seededJitter(&rng, magnitude: jitterAmt * 0.7)
                )
                let mid2 = CGPoint(
                    x: (path.currentPoint?.x ?? start.x) + dx * 0.67 + seededJitter(&rng, magnitude: jitterAmt * 0.7),
                    y: (path.currentPoint?.y ?? start.y) + dy * 0.67 + seededJitter(&rng, magnitude: jitterAmt * 0.7)
                )
                path.addCurve(to: je, control1: mid1, control2: mid2)

                let cornerPt = cornerPoint(for: i, rect: rect)
                let nextStart = corners[(i + 1) % 4].0
                let jNext = CGPoint(x: nextStart.x + seededJitter(&rng, magnitude: jitterAmt) + passOffset,
                                    y: nextStart.y + seededJitter(&rng, magnitude: jitterAmt) + passOffset)
                path.addQuadCurve(to: jNext, control: cornerPt)
            }
            combined.addPath(path)
        }
        return combined
    }

    func sketchyEllipse(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let rx = rect.width / 2, ry = rect.height / 2
        let wobbleAmt = min(rx, ry) * 0.04
        var combined = Path()
        let segments = 32

        for pass in 0..<2 {
            var rng = makeRNG(for: rect, pass: pass)
            let passOffset = pass == 0 ? wobbleAmt * 0.4 : -wobbleAmt * 0.4
            var path = Path()

            for i in 0...segments {
                let angle = (Double(i) / Double(segments)) * 2 * .pi
                let rJitter = seededJitter(&rng, magnitude: wobbleAmt) + passOffset
                let px = cx + (rx + rJitter) * cos(angle)
                let py = cy + (ry + rJitter) * sin(angle)
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            combined.addPath(path)
        }
        return combined
    }

    func sketchyTriangle(in rect: CGRect) -> Path {
        let size = max(rect.width, rect.height)
        let jitterAmt = size * 0.012
        var combined = Path()
        let vertices = [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ]

        for pass in 0..<2 {
            var rng = makeRNG(for: rect, pass: pass)
            let passOffset = pass == 0 ? jitterAmt * 0.3 : -jitterAmt * 0.3
            var path = Path()

            let start = CGPoint(x: vertices[0].x + seededJitter(&rng, magnitude: jitterAmt) + passOffset,
                                y: vertices[0].y + seededJitter(&rng, magnitude: jitterAmt) + passOffset)
            path.move(to: start)

            for i in 1...3 {
                let v = vertices[i % 3]
                let target = CGPoint(x: v.x + seededJitter(&rng, magnitude: jitterAmt) + passOffset,
                                     y: v.y + seededJitter(&rng, magnitude: jitterAmt) + passOffset)
                let dx = target.x - (path.currentPoint?.x ?? start.x)
                let dy = target.y - (path.currentPoint?.y ?? start.y)
                let mid = CGPoint(
                    x: (path.currentPoint?.x ?? start.x) + dx * 0.5 + seededJitter(&rng, magnitude: jitterAmt * 0.7),
                    y: (path.currentPoint?.y ?? start.y) + dy * 0.5 + seededJitter(&rng, magnitude: jitterAmt * 0.7)
                )
                path.addQuadCurve(to: target, control: mid)
            }
            combined.addPath(path)
        }
        return combined
    }

    func sketchyLinePath(from start: CGPoint, to end: CGPoint) -> Path {
        let len = hypot(end.x - start.x, end.y - start.y)
        let jitterAmt = max(1.5, len * 0.01)
        let rect = CGRect(x: start.x, y: start.y, width: end.x - start.x, height: end.y - start.y)
        var combined = Path()

        for pass in 0..<2 {
            var rng = makeRNG(for: rect, pass: pass)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let perpX = -dy / max(len, 1)
            let perpY = dx / max(len, 1)
            let passOffset = pass == 0 ? jitterAmt * 0.5 : -jitterAmt * 0.3

            let s = CGPoint(x: start.x + perpX * passOffset, y: start.y + perpY * passOffset)
            let e = CGPoint(x: end.x + perpX * passOffset, y: end.y + perpY * passOffset)
            let mid = CGPoint(
                x: (s.x + e.x) / 2 + perpX * seededJitter(&rng, magnitude: jitterAmt),
                y: (s.y + e.y) / 2 + perpY * seededJitter(&rng, magnitude: jitterAmt)
            )

            var path = Path()
            path.move(to: s)
            path.addQuadCurve(to: e, control: mid)
            combined.addPath(path)
        }
        return combined
    }

    func sketchyLine(path: inout Path, to end: CGPoint, roughness: Double) {
        let start = path.currentPoint ?? end
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len = hypot(dx, dy)
        let bow = len * 0.01 * roughness
        let perpX = -dy / max(len, 1) * bow
        let perpY = dx / max(len, 1) * bow
        let mid = CGPoint(x: start.x + dx * 0.5 + perpX, y: start.y + dy * 0.5 + perpY)
        path.addQuadCurve(to: end, control: mid)
    }

    private func cornerPoint(for index: Int, rect: CGRect) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: rect.maxX, y: rect.minY)
        case 1: return CGPoint(x: rect.maxX, y: rect.maxY)
        case 2: return CGPoint(x: rect.minX, y: rect.maxY)
        default: return CGPoint(x: rect.minX, y: rect.minY)
        }
    }
}
