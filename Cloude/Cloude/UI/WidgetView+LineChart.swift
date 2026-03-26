import SwiftUI
import Charts

struct LineChartWidget: View {
    let data: [String: Any]

    @State private var selectedX: Double?

    private var title: String? { data["title"] as? String }
    private var xLabel: String? { data["xLabel"] as? String }
    private var yLabel: String? { data["yLabel"] as? String }
    private var lines: [(label: String, points: [(x: Double, y: Double)])] {
        guard let arr = data["lines"] as? [[String: Any]] else { return [] }
        return arr.compactMap { line in
            guard let label = line["label"] as? String,
                  let pts = line["points"] as? [[String: Any]] else { return nil }
            let points = pts.compactMap { pt -> (x: Double, y: Double)? in
                guard let x = pt["x"] as? Double,
                      let y = pt["y"] as? Double else { return nil }
                return (x: x, y: y)
            }
            return (label: label, points: points)
        }
    }

    private let colors: [Color] = [.blue, .orange, .green, .purple, .red, .teal]

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "chart.line.uptrend.xyaxis", title: title ?? "Line Chart", color: .blue)

            Chart {
                ForEach(Array(lines.enumerated()), id: \.offset) { lineIdx, line in
                    ForEach(Array(line.points.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value(xLabel ?? "X", point.x),
                            y: .value(yLabel ?? "Y", point.y)
                        )
                        .foregroundStyle(colors[lineIdx % colors.count])
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .symbol(Circle().strokeBorder(lineWidth: 1.5))
                    .symbolSize(20)
                }

                if let selectedX {
                    RuleMark(x: .value("Selected", selectedX))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .center) {
                            valuesAtX(selectedX)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().font(.system(size: DS.Text.s, design: .monospaced))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().font(.system(size: DS.Text.s, design: .monospaced))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let x = drag.location.x - geo[proxy.plotFrame!].origin.x
                                    if let xVal: Double = proxy.value(atX: x) {
                                        withAnimation(.easeOut(duration: 0.1)) {
                                            selectedX = xVal
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedX = nil
                                    }
                                }
                        )
                }
            }
            .sensoryFeedback(.selection, trigger: selectedX != nil)

            if lines.count > 1 {
                FlowLayout(spacing: 12) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colors[index % colors.count])
                                .frame(width: 8, height: 8)
                            Text(line.label)
                                .font(.system(size: DS.Text.s))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func valuesAtX(_ x: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(x.formatted())
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            ForEach(Array(lines.enumerated()), id: \.offset) { lineIdx, line in
                if let closest = line.points.min(by: { abs($0.x - x) < abs($1.x - x) }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colors[lineIdx % colors.count])
                            .frame(width: 6, height: 6)
                        Text(closest.y.formatted())
                            .font(.system(size: DS.Text.s, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}
