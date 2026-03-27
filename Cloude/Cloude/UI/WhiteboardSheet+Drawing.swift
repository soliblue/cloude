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
            return StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: join, dash: [DS.Spacing.s, DS.Spacing.xs])
        case "dotted":
            return StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: join, dash: [DS.Spacing.xs, DS.Spacing.xs])
        default:
            return StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: join)
        }
    }

    func selectionOverlay(for element: WhiteboardElement) -> some View {
        let frame = store.screenFrame(for: element, canvasSize: canvasSize)
        return Rectangle()
            .strokeBorder(Color.accentColor.opacity(DS.Opacity.half), style: StrokeStyle(lineWidth: DS.Stroke.regular, dash: [DS.Spacing.xs, DS.Spacing.xs]))
            .frame(width: frame.width + DS.Spacing.s, height: frame.height + DS.Spacing.s)
            .position(x: frame.position.x + frame.width / 2, y: frame.position.y + frame.height / 2)
            .allowsHitTesting(false)
    }

    func arrowSourceOverlay(for element: WhiteboardElement) -> some View {
        let frame = store.screenFrame(for: element, canvasSize: canvasSize)
        return ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.m)
                .fill(Color.accentColor.opacity(DS.Opacity.light))
                .frame(width: frame.width + DS.Spacing.l, height: frame.height + DS.Spacing.l)
            RoundedRectangle(cornerRadius: DS.Radius.m)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: DS.Stroke.thick, dash: [DS.Size.xxs, DS.Spacing.xs]))
                .frame(width: frame.width + DS.Spacing.l, height: frame.height + DS.Spacing.l)
            Text("From")
                .font(.system(size: DS.Text.s, weight: .semibold))
                .foregroundColor(.accentColor)
                .offset(y: -(frame.height / 2 + DS.Icon.l))
        }
        .position(x: frame.position.x + frame.width / 2, y: frame.position.y + frame.height / 2)
        .allowsHitTesting(false)
    }
}
