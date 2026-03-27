import SwiftUI

struct InteractiveFunctionWidget: View {
    let data: [String: Any]
    @State private var inputValues: [String: Double] = [:]
    @State private var initialized = false

    private var name: String { data["name"] as? String ?? "Calculator" }
    private var formula: String { data["formula"] as? String ?? "0" }

    private var inputDefs: [(name: String, value: Double, unit: String?, min: Double, max: Double, step: Double)] {
        guard let inputs = data["inputs"] as? [String: [String: Any]] else { return [] }
        return inputs.compactMap { key, val in
            guard let value = val["value"] as? Double,
                  let min = val["min"] as? Double,
                  let max = val["max"] as? Double else { return nil }
            let step = val["step"] as? Double ?? (max - min) / 100
            let unit = val["unit"] as? String
            return (name: key, value: value, unit: unit, min: min, max: max, step: step)
        }.sorted { $0.name < $1.name }
    }

    private var outputConfig: (label: String, unit: String?, format: String) {
        guard let output = data["output"] as? [String: Any] else { return ("Result", nil, "%.2f") }
        return (
            label: output["label"] as? String ?? "Result",
            unit: output["unit"] as? String,
            format: output["format"] as? String ?? "%.2f"
        )
    }

    private var computedResult: Double {
        ExpressionParser.evaluateOrZero(formula, variables: inputValues)
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "slider.horizontal.3", title: name, color: .purple)

            ForEach(inputDefs, id: \.name) { input in
                inputSlider(input)
            }

            resultView
        }
        .onAppear {
            if !initialized {
                for input in inputDefs { inputValues[input.name] = input.value }
                initialized = true
            }
        }
    }

    private func inputSlider(_ input: (name: String, value: Double, unit: String?, min: Double, max: Double, step: Double)) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(input.name)
                    .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: DS.Spacing.xs) {
                    Text(String(format: "%.1f", inputValues[input.name] ?? input.value))
                        .font(.system(size: DS.Text.m, weight: .medium, design: .monospaced))
                    if let unit = input.unit {
                        Text(unit)
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Slider(
                value: Binding(
                    get: { inputValues[input.name] ?? input.value },
                    set: { inputValues[input.name] = $0 }
                ),
                in: input.min...input.max,
                step: input.step
            )
            .tint(.purple)
        }
    }

    private var resultView: some View {
        HStack {
            Text(outputConfig.label)
                .font(.system(size: DS.Text.m, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: DS.Spacing.xs) {
                Text(String(format: outputConfig.format, computedResult))
                    .font(.system(size: DS.Icon.l, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: DS.Duration.s), value: computedResult)
                if let unit = outputConfig.unit {
                    Text(unit)
                        .font(.system(size: DS.Text.m, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(DS.Spacing.m)
        .background(Color.purple.opacity(DS.Opacity.s))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
    }
}
