import SwiftUI
import Charts

struct FunctionPlotWidget: View {
    let data: [String: Any]
    @State private var paramValues: [String: Double] = [:]
    @State private var initialized = false

    private var expression: String { data["expression"] as? String ?? "x" }
    private var xRange: (Double, Double) {
        if let arr = data["xRange"] as? [Double], arr.count == 2 { return (arr[0], arr[1]) }
        return (-10, 10)
    }
    private var yRange: (Double, Double)? {
        if let arr = data["yRange"] as? [Double], arr.count == 2 { return (arr[0], arr[1]) }
        return nil
    }
    private var paramDefs: [(name: String, value: Double, min: Double, max: Double, step: Double)] {
        guard let params = data["params"] as? [String: [String: Any]] else { return [] }
        return params.compactMap { key, val in
            guard let value = val["value"] as? Double,
                  let min = val["min"] as? Double,
                  let max = val["max"] as? Double else { return nil }
            let step = val["step"] as? Double ?? (max - min) / 100
            return (name: key, value: value, min: min, max: max, step: step)
        }.sorted { $0.name < $1.name }
    }

    private var points: [(x: Double, y: Double)] {
        let (xMin, xMax) = xRange
        let steps = 200
        let dx = (xMax - xMin) / Double(steps)
        var vars = paramValues
        return (0...steps).compactMap { i in
            let x = xMin + Double(i) * dx
            vars["x"] = x
            if let y = ExpressionParser.evaluate(expression, variables: vars) {
                return (x: x, y: y)
            }
            return nil
        }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "chart.xyaxis.line", title: "Function Plot", color: .blue)

            Text("f(x) = \(expression)")
                .font(.system(size: DS.Text.m, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)

            chart
                .frame(height: 200)

            ForEach(paramDefs, id: \.name) { param in
                paramSlider(param)
            }
        }
        .onAppear {
            if !initialized {
                for param in paramDefs { paramValues[param.name] = param.value }
                initialized = true
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("x", point.x), y: .value("y", point.y))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXScale(domain: xRange.0...xRange.1)
        .chartYScale(domain: yScaleDomain)
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
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
    }

    private var yScaleDomain: ClosedRange<Double> {
        if let yr = yRange { return yr.0...yr.1 }
        let ys = points.map(\.y)
        let yMin = ys.min() ?? -1
        let yMax = ys.max() ?? 1
        let padding = max((yMax - yMin) * 0.1, 0.5)
        return (yMin - padding)...(yMax + padding)
    }

    private func paramSlider(_ param: (name: String, value: Double, min: Double, max: Double, step: Double)) -> some View {
        HStack(spacing: 8) {
            Text(param.name)
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { paramValues[param.name] ?? param.value },
                    set: { paramValues[param.name] = $0 }
                ),
                in: param.min...param.max,
                step: param.step
            )
            .tint(.blue)

            Text(String(format: "%.2f", paramValues[param.name] ?? param.value))
                .font(.system(size: DS.Text.s, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 45, alignment: .trailing)
        }
    }
}
