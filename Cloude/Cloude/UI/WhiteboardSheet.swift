// WhiteboardSheet.swift

import SwiftUI

struct WhiteboardSheet: View {
    @ObservedObject var store: WhiteboardStore
    @Environment(\.dismiss) var dismiss
    @State var canvasSize: CGSize = .zero
    @State var dragIntent: DragIntent?
    @State var panStart: CGPoint?
    @State var editingTextId: String?
    @State var editingTextValue: String = ""
    @FocusState var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.themeBackground
                        .ignoresSafeArea()

                    whiteboardCanvas
                        .onAppear { canvasSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in canvasSize = newSize }

                    WhiteboardGestureView(
                        onTap: { point in handleGestureTap(at: point) },
                        onDoubleTap: { point in handleGestureDoubleTap(at: point) },
                        onOneDrag: { phase, start, current, translation in
                            handleGestureOneDrag(phase: phase, start: start, current: current, translation: translation)
                        },
                        onTwoPan: { phase, translation in
                            handleGestureTwoPan(phase: phase, translation: translation)
                        },
                        onPinch: { phase, scale in
                            handleGesturePinch(phase: phase, scale: scale)
                        }
                    )

                    if let selectedId = store.selectedElementId,
                       let element = store.state.elements.first(where: { $0.id == selectedId }) {
                        selectionOverlay(for: element)
                    }

                    if let sourceId = store.arrowSourceId,
                       let sourceEl = store.state.elements.first(where: { $0.id == sourceId }) {
                        arrowSourceOverlay(for: sourceEl)
                    }

                    VStack {
                        Spacer()
                        floatingToolbar
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Whiteboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .background(Color.themeBackground)
    }

    private var whiteboardCanvas: some View {
        Canvas { context, size in
            let viewport = store.state.viewport
            let s = size.width / 1000.0 * viewport.zoom

            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: s, y: s)
            context.translateBy(x: viewport.x - 500, y: viewport.y - 500)

            drawGrid(context: context)

            let elementDict = Dictionary(store.state.elements.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            for element in store.state.elements {
                drawElement(element, context: context, elementDict: elementDict)
            }
        }
    }

    private func drawGrid(context: GraphicsContext) {
        let gridColor = Color.white.opacity(0.04)
        for i in stride(from: 0, through: 1000, by: 50) {
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: Double(i)))
            hPath.addLine(to: CGPoint(x: 1000, y: Double(i)))
            context.stroke(hPath, with: .color(gridColor), lineWidth: 0.5)

            var vPath = Path()
            vPath.move(to: CGPoint(x: Double(i), y: 0))
            vPath.addLine(to: CGPoint(x: Double(i), y: 1000))
            context.stroke(vPath, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawElement(_ element: WhiteboardElement, context: GraphicsContext, elementDict: [String: WhiteboardElement]) {
        switch element.type {
        case .rect, .ellipse:
            drawShape(element, context: context)
        case .text:
            drawText(element, context: context)
        case .path:
            drawPath(element, context: context)
        case .arrow:
            drawArrow(element, context: context, elementDict: elementDict)
        }
    }

    private func drawShape(_ element: WhiteboardElement, context: GraphicsContext) {
        let isSelected = element.id == store.selectedElementId
        let fillColor = element.fill.map { Color(hexString: $0) } ?? Color.accentColor.opacity(0.15)
        let strokeColor = element.stroke.map { Color(hexString: $0) } ?? Color.white.opacity(0.6)
        let rect = CGRect(x: element.x, y: element.y, width: element.w, height: element.h)
        let path = element.type == .rect ? RoundedRectangle(cornerRadius: 6).path(in: rect) : Ellipse().path(in: rect)
        context.fill(path, with: .color(fillColor))
        context.stroke(path, with: .color(isSelected ? Color.accentColor : strokeColor), lineWidth: isSelected ? 2 : 1)
        if let label = element.label {
            let text = Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        }
    }

    private func drawText(_ element: WhiteboardElement, context: GraphicsContext) {
        let text = Text(element.label ?? "")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
        context.draw(text, at: CGPoint(x: element.x, y: element.y), anchor: .topLeading)
    }

    private func drawPath(_ element: WhiteboardElement, context: GraphicsContext) {
        if let points = element.points, points.count > 1 {
            let isSelected = element.id == store.selectedElementId
            let fillColor = element.fill.map { Color(hexString: $0) } ?? Color.accentColor.opacity(0.15)
            let strokeColor = element.stroke.map { Color(hexString: $0) } ?? Color.white.opacity(0.6)
            var path = Path()
            path.move(to: CGPoint(x: points[0][0], y: points[0][1]))
            for i in 1..<points.count {
                path.addLine(to: CGPoint(x: points[i][0], y: points[i][1]))
            }
            if element.closed == true {
                path.closeSubpath()
                context.fill(path, with: .color(fillColor))
            }
            context.stroke(path, with: .color(isSelected ? Color.accentColor : strokeColor), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawArrow(_ element: WhiteboardElement, context: GraphicsContext, elementDict: [String: WhiteboardElement]) {
        if let fromId = element.from, let toId = element.to,
           let fromEl = elementDict[fromId],
           let toEl = elementDict[toId] {
            let isSelected = element.id == store.selectedElementId
            let strokeColor = element.stroke.map { Color(hexString: $0) } ?? Color.white.opacity(0.6)
            let fromCenter = CGPoint(x: fromEl.x + fromEl.w / 2, y: fromEl.y + fromEl.h / 2)
            let toCenter = CGPoint(x: toEl.x + toEl.w / 2, y: toEl.y + toEl.h / 2)
            let fromEdge = edgePoint(of: fromEl, toward: toCenter)
            let toEdge = edgePoint(of: toEl, toward: fromCenter)

            var path = Path()
            path.move(to: fromEdge)
            path.addLine(to: toEdge)
            context.stroke(path, with: .color(isSelected ? Color.accentColor : strokeColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            let angle = atan2(toEdge.y - fromEdge.y, toEdge.x - fromEdge.x)
            let arrowLen: Double = 10
            let arrowAngle: Double = .pi / 6
            var arrowPath = Path()
            arrowPath.move(to: toEdge)
            arrowPath.addLine(to: CGPoint(
                x: toEdge.x - arrowLen * cos(angle - arrowAngle),
                y: toEdge.y - arrowLen * sin(angle - arrowAngle)
            ))
            arrowPath.move(to: toEdge)
            arrowPath.addLine(to: CGPoint(
                x: toEdge.x - arrowLen * cos(angle + arrowAngle),
                y: toEdge.y - arrowLen * sin(angle + arrowAngle)
            ))
            context.stroke(arrowPath, with: .color(isSelected ? Color.accentColor : strokeColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            if let label = element.label {
                let mid = CGPoint(x: (fromEdge.x + toEdge.x) / 2, y: (fromEdge.y + toEdge.y) / 2 - 10)
                let text = Text(label).font(.system(size: 10)).foregroundColor(.secondary)
                context.draw(text, at: mid, anchor: .center)
            }
        }
    }

    private func edgePoint(of element: WhiteboardElement, toward target: CGPoint) -> CGPoint {
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

    private func selectionOverlay(for element: WhiteboardElement) -> some View {
        let frame = store.screenFrame(for: element, canvasSize: canvasSize)
        return Rectangle()
            .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(width: frame.width + 8, height: frame.height + 8)
            .position(x: frame.position.x + frame.width / 2, y: frame.position.y + frame.height / 2)
            .allowsHitTesting(false)
    }

    private func arrowSourceOverlay(for element: WhiteboardElement) -> some View {
        let frame = store.screenFrame(for: element, canvasSize: canvasSize)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: frame.width + 16, height: frame.height + 16)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: frame.width + 16, height: frame.height + 16)
            Text("From")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.accentColor)
                .offset(y: -(frame.height / 2 + 18))
        }
        .position(x: frame.position.x + frame.width / 2, y: frame.position.y + frame.height / 2)
        .allowsHitTesting(false)
    }
}
