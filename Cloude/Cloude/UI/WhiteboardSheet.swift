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
            let scale = size.width / 1000.0 * viewport.zoom

            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
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
        let isSelected = element.id == store.selectedElementId
        let fillColor = element.fill.map { Color(hexString: $0) } ?? Color.accentColor.opacity(0.15)
        let strokeColor = element.stroke.map { Color(hexString: $0) } ?? Color.white.opacity(0.6)

        switch element.type {
        case .rect, .ellipse:
            let rect = CGRect(x: element.x, y: element.y, width: element.w, height: element.h)
            let path = element.type == .rect ? RoundedRectangle(cornerRadius: 6).path(in: rect) : Ellipse().path(in: rect)
            context.fill(path, with: .color(fillColor))
            context.stroke(path, with: .color(isSelected ? Color.accentColor : strokeColor), lineWidth: isSelected ? 2 : 1)
            if let label = element.label {
                drawLabel(label, in: rect, context: context)
            }

        case .text:
            let text = Text(element.label ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            context.draw(text, at: CGPoint(x: element.x, y: element.y), anchor: .topLeading)

        case .path:
            if let points = element.points, points.count > 1 {
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

        case .arrow:
            if let fromId = element.from, let toId = element.to,
               let fromEl = elementDict[fromId],
               let toEl = elementDict[toId] {
                let fromCenter = CGPoint(x: fromEl.x + fromEl.w / 2, y: fromEl.y + fromEl.h / 2)
                let toCenter = CGPoint(x: toEl.x + toEl.w / 2, y: toEl.y + toEl.h / 2)

                var path = Path()
                path.move(to: fromCenter)
                path.addLine(to: toCenter)
                context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                let angle = atan2(toCenter.y - fromCenter.y, toCenter.x - fromCenter.x)
                let arrowLen: Double = 10
                let arrowAngle: Double = .pi / 6
                var arrowPath = Path()
                arrowPath.move(to: toCenter)
                arrowPath.addLine(to: CGPoint(
                    x: toCenter.x - arrowLen * cos(angle - arrowAngle),
                    y: toCenter.y - arrowLen * sin(angle - arrowAngle)
                ))
                arrowPath.move(to: toCenter)
                arrowPath.addLine(to: CGPoint(
                    x: toCenter.x - arrowLen * cos(angle + arrowAngle),
                    y: toCenter.y - arrowLen * sin(angle + arrowAngle)
                ))
                context.stroke(arrowPath, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                if let label = element.label {
                    let mid = CGPoint(x: (fromCenter.x + toCenter.x) / 2, y: (fromCenter.y + toCenter.y) / 2 - 10)
                    let text = Text(label).font(.system(size: 10)).foregroundColor(.secondary)
                    context.draw(text, at: mid, anchor: .center)
                }
            }
        }
    }

    private func drawLabel(_ label: String, in rect: CGRect, context: GraphicsContext) {
        let text = Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
        context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    private func selectionOverlay(for element: WhiteboardElement) -> some View {
        let screenPos = store.boardToScreen(
            CGPoint(x: element.x, y: element.y),
            viewport: store.state.viewport,
            canvasSize: canvasSize
        )
        let scale = canvasSize.width / 1000.0 * store.state.viewport.zoom
        let screenW = element.w * scale
        let screenH = element.h * scale

        return Rectangle()
            .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(width: screenW + 8, height: screenH + 8)
            .position(x: screenPos.x + screenW / 2, y: screenPos.y + screenH / 2)
            .allowsHitTesting(false)
    }

    private func arrowSourceOverlay(for element: WhiteboardElement) -> some View {
        let screenPos = store.boardToScreen(
            CGPoint(x: element.x, y: element.y),
            viewport: store.state.viewport,
            canvasSize: canvasSize
        )
        let scale = canvasSize.width / 1000.0 * store.state.viewport.zoom
        let screenW = element.w * scale
        let screenH = element.h * scale

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: screenW + 16, height: screenH + 16)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: screenW + 16, height: screenH + 16)
            Text("From")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.accentColor)
                .offset(y: -(screenH / 2 + 18))
        }
        .position(x: screenPos.x + screenW / 2, y: screenPos.y + screenH / 2)
        .allowsHitTesting(false)
    }

}
