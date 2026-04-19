import SwiftUI

struct WhiteboardSheet: View {
    @ObservedObject var store: WhiteboardStore
    var onSendSnapshot: (() -> Void)?
    var isConnected: Bool = false
    @Environment(\.dismiss) var dismiss
    @State var canvasSize: CGSize = .zero
    @State var dragIntent: DragIntent?
    @State var panStart: CGPoint?
    @State var editingTextId: String?
    @State var editingTextValue: String = ""
    @State var showExportSuccess = false
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

                    ForEach(store.state.elements.filter { store.selectedElementIds.contains($0.id) && $0.type != .arrow }) { element in
                        selectionOverlay(for: element)
                    }

                    if let sourceId = store.arrowSourceId,
                       let sourceEl = store.state.elements.first(where: { $0.id == sourceId }) {
                        arrowSourceOverlay(for: sourceEl)
                    }

                    VStack {
                        Spacer()
                        floatingToolbar
                            .padding(.bottom, DS.Spacing.l)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                if showExportSuccess {
                    Text("Saved to Photos")
                        .font(.system(size: DS.Text.m, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.l)
                        .padding(.vertical, DS.Spacing.s)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, DS.Spacing.l)
                }
            }
            .animation(.quickTransition, value: showExportSuccess)
        }
        .background(Color.themeBackground)
        .agenticID("whiteboard_view")
    }

    private var whiteboardCanvas: some View {
        Canvas { context, size in
            let viewport = store.state.viewport
            let s = size.width / 1000.0 * viewport.zoom

            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: s, y: s)
            context.translateBy(x: viewport.x - 500, y: viewport.y - 500)

            drawGrid(context: context)

            let sorted = store.state.elements.sorted { ($0.z ?? 0) < ($1.z ?? 0) }
            let elementDict = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            for element in sorted {
                drawElement(element, context: context, elementDict: elementDict)
            }
        }
    }

    private func drawGrid(context: GraphicsContext) {
        let gridColor = Color.white.opacity(DS.Opacity.s)
        for i in stride(from: 0, through: 1000, by: 50) {
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: Double(i)))
            hPath.addLine(to: CGPoint(x: 1000, y: Double(i)))
            context.stroke(hPath, with: .color(gridColor), lineWidth: DS.Stroke.s)

            var vPath = Path()
            vPath.move(to: CGPoint(x: Double(i), y: 0))
            vPath.addLine(to: CGPoint(x: Double(i), y: 1000))
            context.stroke(vPath, with: .color(gridColor), lineWidth: DS.Stroke.s)
        }
    }
}
