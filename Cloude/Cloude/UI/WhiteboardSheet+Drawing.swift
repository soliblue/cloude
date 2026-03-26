// WhiteboardSheet+Drawing.swift

import SwiftUI

extension WhiteboardSheet {
    func drawElement(_ element: WhiteboardElement, context: GraphicsContext, elementDict: [String: WhiteboardElement]) {
        switch element.type {
        case .rect, .ellipse, .triangle:
            drawShape(element, context: context)
        case .text:
            drawText(element, context: context)
        case .path:
            drawPath(element, context: context)
        case .arrow:
            drawArrow(element, context: context, elementDict: elementDict)
        }
    }

    func edgePoint(of element: WhiteboardElement, toward target: CGPoint) -> CGPoint {
        let cx = element.x + element.w / 2
        let cy = element.y + element.h / 2
        let dx = target.x - cx
        let dy = target.y - cy
        if dx == 0 && dy == 0 { return CGPoint(x: cx, y: cy) }

        if element.type == .ellipse {
            let rx = element.w / 2
            let ry = element.h / 2
            let angle = atan2(dy, dx)
            return CGPoint(x: cx + rx * cos(angle), y: cy + ry * sin(angle))
        }

        let hw = element.w / 2
        let hh = element.h / 2
        let scaleX = abs(dx) > 0 ? hw / abs(dx) : .infinity
        let scaleY = abs(dy) > 0 ? hh / abs(dy) : .infinity
        let s = min(scaleX, scaleY)
        return CGPoint(x: cx + dx * s, y: cy + dy * s)
    }

    func strokeStyle(width: Double, style: String?, round: Bool = false) -> StrokeStyle {
        let cap: CGLineCap = round ? .round : .butt
        let join: CGLineJoin = round ? .round : .miter
        switch style {
        case "dashed":
            return StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: join, dash: [8, 4])
        case "dotted":
            return StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: join, dash: [2, 4])
        default:
            return StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: join)
        }
    }

    func selectionOverlay(for element: WhiteboardElement) -> some View {
        let frame = store.screenFrame(for: element, canvasSize: canvasSize)
        return Rectangle()
            .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(width: frame.width + 8, height: frame.height + 8)
            .position(x: frame.position.x + frame.width / 2, y: frame.position.y + frame.height / 2)
            .allowsHitTesting(false)
    }

    func arrowSourceOverlay(for element: WhiteboardElement) -> some View {
        let frame = store.screenFrame(for: element, canvasSize: canvasSize)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: frame.width + 16, height: frame.height + 16)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: frame.width + 16, height: frame.height + 16)
            Text("From")
                .font(.system(size: DS.Text.s, weight: .semibold))
                .foregroundColor(.accentColor)
                .offset(y: -(frame.height / 2 + 18))
        }
        .position(x: frame.position.x + frame.width / 2, y: frame.position.y + frame.height / 2)
        .allowsHitTesting(false)
    }
}
