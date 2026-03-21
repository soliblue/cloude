import SwiftUI
import Charts

struct ScatterPlotWidget: View {
    let data: [String: Any]

    @State private var selectedPoint: Int?

    private var title: String? { data["title"] as? String }
    private var xLabel: String? { data["xLabel"] as? String }
    private var yLabel: String? { data["yLabel"] as? String }
    private var points: [(x: Double, y: Double, label: String?)] {
        guard let arr = data["points"] as? [[String: Any]] else { return [] }
        return arr.compactMap { pt in
            guard let x = pt["x"] as? Double,
                  let y = pt["y"] as? Double else { return nil }
            return (x: x, y: y, label: pt["label"] as? String)
        }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "chart.dots.scatter", title: title ?? "Scatter Plot", color: .teal)

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    PointMark(
                        x: .value(xLabel ?? "X", point.x),
                        y: .value(yLabel ?? "Y", point.y)
                    )
                    .foregroundStyle(.teal.opacity(selectedPoint == nil || selectedPoint == index ? 1 : 0.2))
                    .symbolSize(selectedPoint == index ? 80 : 40)
                    .annotation(position: .top) {
                        if selectedPoint == index {
                            VStack(spacing: 1) {
                                if let label = point.label {
                                    Text(label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                Text("(\(point.x.formatted()), \(point.y.formatted()))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().font(.system(size: 9, design: .monospaced))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().font(.system(size: 9, design: .monospaced))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let origin = geo[proxy.plotFrame!].origin
                                    let tapX = drag.location.x - origin.x
                                    let tapY = drag.location.y - origin.y
                                    guard let xVal: Double = proxy.value(atX: tapX),
                                          let yVal: Double = proxy.value(atY: tapY) else { return }
                                    let nearest = points.enumerated().min(by: {
                                        let d1 = pow($0.element.x - xVal, 2) + pow($0.element.y - yVal, 2)
                                        let d2 = pow($1.element.x - xVal, 2) + pow($1.element.y - yVal, 2)
                                        return d1 < d2
                                    })
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        selectedPoint = nearest?.offset
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedPoint = nil
                                    }
                                }
                        )
                }
            }
            .sensoryFeedback(.selection, trigger: selectedPoint)

            if xLabel != nil || yLabel != nil {
                HStack {
                    if let xLabel {
                        Text("X: \(xLabel)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let yLabel {
                        Text("Y: \(yLabel)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
