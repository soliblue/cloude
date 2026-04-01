// WhiteboardSheet+DrawShapes.swift

import SwiftUI

extension WhiteboardSheet {
    static let sketchStrokeColor = Color.white.opacity(DS.Opacity.l)

    func drawShape(_ element: WhiteboardElement, context: GraphicsContext) {
        let isSelected = store.selectedIds.contains(element.id)
        let fillColor = element.fill.map { Color(hexString: $0) } ?? Color.accentColor.opacity(DS.Opacity.s)
        let rect = CGRect(x: element.x, y: element.y, width: element.w, height: element.h)
        let cleanPath: Path
        let sketchPath: Path
        switch element.type {
        case .rect:
            cleanPath = RoundedRectangle(cornerRadius: DS.Radius.s).path(in: rect)
            sketchPath = sketchyRoundedRect(in: rect, cornerRadius: DS.Radius.s)
        case .ellipse:
            cleanPath = Ellipse().path(in: rect)
            sketchPath = sketchyEllipse(in: rect)
        case .triangle:
            cleanPath = trianglePath(in: rect)
            sketchPath = sketchyTriangle(in: rect)
        default:
            return
        }
        var ctx = context
        if let opacity = element.opacity { ctx.opacity = opacity }
        ctx.fill(cleanPath, with: .color(fillColor))
        let lineWidth = element.strokeWidth ?? 1
        let style = strokeStyle(width: lineWidth, style: element.strokeStyle)
        let color = isSelected ? Color.accentColor : Self.sketchStrokeColor
        ctx.stroke(sketchPath, with: .color(color), style: style)
        if let label = element.label {
            let size = element.fontSize ?? 12
            let maxWidth = rect.width - (element.type == .triangle ? rect.width * 0.3 : 12)
            let labelY = element.type == .triangle ? rect.midY + rect.height * 0.08 : rect.midY
            let labelColor: Color = {
                if let fill = element.fill {
                    let hex = fill.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                    var value: UInt64 = 0
                    if Scanner(string: hex).scanHexInt64(&value), hex.count == 6 {
                        let red = Double((value >> 16) & 0xff) / 255
                        let green = Double((value >> 8) & 0xff) / 255
                        let blue = Double(value & 0xff) / 255
                        return (0.299 * red + 0.587 * green + 0.114 * blue) > 0.6 ? .black : .white
                    }
                }
                return .white
            }()
            drawWrappedText(label, in: ctx, fontSize: size, color: labelColor, maxWidth: maxWidth, center: CGPoint(x: rect.midX, y: labelY))
        }
    }

    func trianglePath(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func drawText(_ element: WhiteboardElement, context: GraphicsContext) {
        let size = element.fontSize ?? 14
        let color = element.stroke.map { Color(hexString: $0) } ?? Color.white
        var ctx = context
        if let opacity = element.opacity { ctx.opacity = opacity }
        let center = CGPoint(x: element.x + element.w / 2, y: element.y + element.h / 2)
        drawWrappedText(element.label ?? "", in: ctx, fontSize: size, color: color, maxWidth: element.w, center: center)
    }

    func drawWrappedText(_ text: String, in ctx: GraphicsContext, fontSize: Double, color: Color, maxWidth: Double, center: CGPoint) {
        let font = CTFontCreateWithName("SFProText-Medium" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let words = text.components(separatedBy: " ")
        var lines: [String] = []
        var currentLine = ""
        for word in words {
            let test = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let testSize = (test as NSString).size(withAttributes: attributes)
            if testSize.width > maxWidth && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = word
            } else {
                currentLine = test
            }
        }
        if !currentLine.isEmpty { lines.append(currentLine) }

        let lineHeight = fontSize * 1.3
        let totalHeight = Double(lines.count) * lineHeight
        let startY = center.y - totalHeight / 2 + lineHeight / 2

        for (i, line) in lines.enumerated() {
            let resolved = ctx.resolve(Text(line).font(.system(size: fontSize, weight: .medium)).foregroundColor(color))
            ctx.draw(resolved, at: CGPoint(x: center.x, y: startY + Double(i) * lineHeight), anchor: .center)
        }
    }
}
