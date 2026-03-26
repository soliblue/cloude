// WhiteboardSheet+DrawPaths.swift

import SwiftUI

extension WhiteboardSheet {
    func drawPath(_ element: WhiteboardElement, context: GraphicsContext) {
        if let points = element.points?.filter({ $0.count >= 2 }), points.count > 1 {
            let isSelected = store.selectedIds.contains(element.id)
            let fillColor = element.fill.map { Color(hexString: $0) } ?? Color.accentColor.opacity(DS.Opacity.light)
            let strokeColor = isSelected ? Color.accentColor : Self.sketchStrokeColor
            var path = Path()
            path.move(to: CGPoint(x: points[0][0], y: points[0][1]))
            for i in 1..<points.count {
                path.addLine(to: CGPoint(x: points[i][0], y: points[i][1]))
            }
            var ctx = context
            if let opacity = element.opacity { ctx.opacity = opacity }
            if element.closed == true {
                path.closeSubpath()
                ctx.fill(path, with: .color(fillColor))
            }
            let lineWidth = element.strokeWidth ?? 2
            let style = strokeStyle(width: lineWidth, style: element.strokeStyle, round: true)
            ctx.stroke(path, with: .color(strokeColor), style: style)
        }
    }
}
