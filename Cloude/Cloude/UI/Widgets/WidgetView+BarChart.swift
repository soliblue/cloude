import SwiftUI
import Charts

struct BarChartWidget: View {
    let data: [String: Any]

    @State private var selectedBar: Int?

    private var title: String? { data["title"] as? String }
    private var unit: String? { data["unit"] as? String }
    private var barColor: Color {
        switch data["color"] as? String {
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "teal": return .teal
        case "pink": return .pink
        default: return .blue
        }
    }
    private var bars: [(label: String, value: Double)] {
        guard let arr = data["bars"] as? [[String: Any]] else { return [] }
        return arr.compactMap { bar in
            guard let label = bar["label"] as? String,
                  let value = bar["value"] as? Double else { return nil }
            return (label: label, value: value)
        }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "chart.bar", title: title ?? "Bar Chart", color: barColor)

            Chart {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    BarMark(
                        x: .value("Label", bar.label),
                        y: .value("Value", bar.value)
                    )
                    .foregroundStyle(selectedBar == index ? barColor : barColor.opacity(selectedBar == nil ? 1 : 0.3))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if selectedBar == index {
                            Text(formatValue(bar.value))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 9, design: .monospaced))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let x = drag.location.x - geo[proxy.plotFrame!].origin.x
                                    if let label: String = proxy.value(atX: x) {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            selectedBar = bars.firstIndex(where: { $0.label == label })
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedBar = nil
                                    }
                                }
                        )
                }
            }
            .sensoryFeedback(.selection, trigger: selectedBar)

            if let unit {
                Text("Values in \(unit)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        if let unit { return "\(value.formatted()) \(unit)" }
        return value.formatted()
    }
}
