// WhiteboardStore+HitTesting.swift

import Foundation
import SwiftUI

extension WhiteboardStore {
    func elementAt(point: CGPoint, canvasSize: CGSize) -> WhiteboardElement? {
        let boardPoint = screenToBoard(point, canvasSize: canvasSize)
        return state.elements.last { element in
            switch element.type {
            case .triangle:
                let a = CGPoint(x: element.x + element.w / 2, y: element.y)
                let b = CGPoint(x: element.x + element.w, y: element.y + element.h)
                let c = CGPoint(x: element.x, y: element.y + element.h)
                return pointInTriangle(boardPoint, a: a, b: b, c: c)
            case .rect, .text:
                return boardPoint.x >= element.x &&
                       boardPoint.x <= element.x + element.w &&
                       boardPoint.y >= element.y &&
                       boardPoint.y <= element.y + element.h
            case .ellipse:
                let cx = element.x + element.w / 2
                let cy = element.y + element.h / 2
                let rx = element.w / 2
                let ry = element.h / 2
                if rx <= 0 || ry <= 0 { return false }
                let nx = (boardPoint.x - cx) / rx
                let ny = (boardPoint.y - cy) / ry
                return nx * nx + ny * ny <= 1
            case .path:
                if let points = element.points {
                    return points.contains { p in
                        let dx = boardPoint.x - p[0]
                        let dy = boardPoint.y - p[1]
                        return dx * dx + dy * dy < 225
                    }
                }
                return false
            case .arrow:
                if let fromId = element.from, let toId = element.to,
                   let fromEl = state.elements.first(where: { $0.id == fromId }),
                   let toEl = state.elements.first(where: { $0.id == toId }) {
                    let a = CGPoint(x: fromEl.x + fromEl.w / 2, y: fromEl.y + fromEl.h / 2)
                    let b = CGPoint(x: toEl.x + toEl.w / 2, y: toEl.y + toEl.h / 2)
                    return distanceToSegment(boardPoint, a: a, b: b) < 10
                }
                return false
            }
        }
    }

    func pointInTriangle(_ p: CGPoint, a: CGPoint, b: CGPoint, c: CGPoint) -> Bool {
        func sign(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> Double {
            (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
        }
        let d1 = sign(p, a, b)
        let d2 = sign(p, b, c)
        let d3 = sign(p, c, a)
        let hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0)
        let hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0)
        return !(hasNeg && hasPos)
    }

    func distanceToSegment(_ p: CGPoint, a: CGPoint, b: CGPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    func screenToBoard(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        let s = scale(for: canvasSize)
        return CGPoint(
            x: (point.x - canvasSize.width / 2) / s + 500 - state.viewport.x,
            y: (point.y - canvasSize.height / 2) / s + 500 - state.viewport.y
        )
    }

    func boardToScreen(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        let s = scale(for: canvasSize)
        return CGPoint(
            x: (point.x - 500 + state.viewport.x) * s + canvasSize.width / 2,
            y: (point.y - 500 + state.viewport.y) * s + canvasSize.height / 2
        )
    }

    func screenFrame(for element: WhiteboardElement, canvasSize: CGSize) -> (position: CGPoint, width: CGFloat, height: CGFloat) {
        let screenPos = boardToScreen(CGPoint(x: element.x, y: element.y), canvasSize: canvasSize)
        let s = scale(for: canvasSize)
        return (screenPos, element.w * s, element.h * s)
    }

    func simplifyPath(_ points: [[Double]], epsilon: Double) -> [[Double]] {
        let points = points.filter { $0.count >= 2 }
        if points.count <= 2 { return points }
        var maxDist = 0.0
        var maxIndex = 0
        let first = points[0]
        let last = points[points.count - 1]

        for i in 1..<(points.count - 1) {
            let dist = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left = simplifyPath(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = simplifyPath(Array(points[maxIndex..<points.count]), epsilon: epsilon)
            return left.dropLast() + right
        }
        return [first, last]
    }

    private func perpendicularDistance(point: [Double], lineStart: [Double], lineEnd: [Double]) -> Double {
        let dx = lineEnd[0] - lineStart[0]
        let dy = lineEnd[1] - lineStart[1]
        let lineLenSq = dx * dx + dy * dy
        if lineLenSq == 0 {
            let ex = point[0] - lineStart[0]
            let ey = point[1] - lineStart[1]
            return sqrt(ex * ex + ey * ey)
        }
        return abs(dy * point[0] - dx * point[1] + lineEnd[0] * lineStart[1] - lineEnd[1] * lineStart[0]) / sqrt(lineLenSq)
    }
}
