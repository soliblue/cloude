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
}
