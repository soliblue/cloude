import SwiftUI

extension WhiteboardSheet {
    func drawArrow(_ element: WhiteboardElement, context: GraphicsContext, elementDict: [String: WhiteboardElement]) {
        if let fromId = element.from, let toId = element.to,
           let fromEl = elementDict[fromId],
           let toEl = elementDict[toId] {
            let isSelected = store.selectedElementIds.contains(element.id)
            let strokeColor = isSelected ? Color.accentColor : Self.sketchStrokeColor
            let fromCenter = CGPoint(x: fromEl.x + fromEl.w / 2, y: fromEl.y + fromEl.h / 2)
            let toCenter = CGPoint(x: toEl.x + toEl.w / 2, y: toEl.y + toEl.h / 2)
            let fromEdge = edgePoint(of: fromEl, toward: toCenter)
            let toEdge = edgePoint(of: toEl, toward: fromCenter)

            var ctx = context
            if let opacity = element.opacity { ctx.opacity = opacity }
            let lineWidth = element.strokeWidth ?? 1.5
            let style = strokeStyle(width: lineWidth, style: element.strokeStyle, round: true)

            let linePath = sketchyLinePath(from: fromEdge, to: toEdge)
            ctx.stroke(linePath, with: .color(strokeColor), style: style)

            let angle = atan2(toEdge.y - fromEdge.y, toEdge.x - fromEdge.x)
            let arrowLen: Double = 10
            let arrowAngle: Double = .pi / 6
            let tip1 = CGPoint(
                x: toEdge.x - arrowLen * cos(angle - arrowAngle),
                y: toEdge.y - arrowLen * sin(angle - arrowAngle)
            )
            let tip2 = CGPoint(
                x: toEdge.x - arrowLen * cos(angle + arrowAngle),
                y: toEdge.y - arrowLen * sin(angle + arrowAngle)
            )
            var arrowHead = Path()
            arrowHead.move(to: tip1)
            sketchyLine(path: &arrowHead, to: toEdge, roughness: Self.roughness * 0.5)
            sketchyLine(path: &arrowHead, to: tip2, roughness: Self.roughness * 0.5)
            ctx.stroke(arrowHead, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if let label = element.label, !label.isEmpty {
                let mid = CGPoint(x: (fromEdge.x + toEdge.x) / 2, y: (fromEdge.y + toEdge.y) / 2)
                let fontSize = element.fontSize ?? 10
                let text = Text(label)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.white)
                var labelCtx = ctx
                labelCtx.translateBy(x: mid.x, y: mid.y)
                var labelAngle = angle
                if labelAngle > .pi / 2 { labelAngle -= .pi }
                if labelAngle < -.pi / 2 { labelAngle += .pi }
                labelCtx.rotate(by: .radians(labelAngle))
                labelCtx.draw(text, at: CGPoint(x: 0, y: -8), anchor: .center)
            }
        }
    }
}
