import SwiftUI
import Charts

struct PieChartWidget: View {
    let data: [String: Any]

    @State private var selectedSlice: Int?
    @State private var selectedAngleValue: Double?

    private var title: String? { data["title"] as? String }
    private var slices: [(label: String, value: Double)] {
        guard let arr = data["slices"] as? [[String: Any]] else { return [] }
        return arr.compactMap { slice in
            guard let label = slice["label"] as? String,
                  let value = slice["value"] as? Double else { return nil }
            return (label: label, value: value)
        }
    }
    private var total: Double { slices.map(\.value).reduce(0, +) }

    private let colors: [Color] = [.blue, .orange, .green, .purple, .red, .teal, .pink, .indigo, .yellow, .mint]

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "chart.pie", title: title ?? "Pie Chart", color: .orange)

            Chart {
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    let isSelected = selectedSlice == index
                    let inner: CGFloat = isSelected ? 0.45 : 0.5
                    let outer: CGFloat = isSelected ? 1.0 : 0.92
                    let opacity: Double = (selectedSlice == nil || isSelected) ? 1 : 0.3
                    SectorMark(
                        angle: .value(slice.label, slice.value),
                        innerRadius: .ratio(inner),
                        outerRadius: .ratio(outer),
                        angularInset: 1.5
                    )
                    .foregroundStyle(colors[index % colors.count].opacity(opacity))
                    .cornerRadius(4)
                }
            }
            .chartAngleSelection(value: $selectedAngleValue)
            .frame(height: 200)
            .overlay {
                if let idx = selectedSlice {
                    VStack(spacing: 2) {
                        Text(slices[idx].label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(slices[idx].value.formatted())
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(colors[idx % colors.count])
                        Text(total > 0 ? String(format: "%.1f%%", slices[idx].value / total * 100) : "")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .sensoryFeedback(.selection, trigger: selectedSlice)
            .onChange(of: selectedAngleValue) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { updateSelectedSlice() }
            }

            FlowLayout(spacing: 8) {
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    let isActive = selectedSlice == nil || selectedSlice == index
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colors[index % colors.count].opacity(isActive ? 1 : 0.3))
                            .frame(width: 8, height: 8)
                        Text(slice.label)
                            .font(.system(size: 11))
                            .foregroundColor(isActive ? .primary : .secondary)
                        Text(total > 0 ? String(format: "%.0f%%", slice.value / total * 100) : "")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedSlice = selectedSlice == index ? nil : index
                        }
                    }
                }
            }
        }
    }

    private func updateSelectedSlice() {
        guard let value = selectedAngleValue else {
            selectedSlice = nil
            return
        }
        var cumulative = 0.0
        for (index, slice) in slices.enumerated() {
            cumulative += slice.value
            if value <= cumulative {
                selectedSlice = index
                return
            }
        }
    }
}
