import SwiftUI
import Charts

struct InteractiveBarChart<DataPoint: Identifiable>: View {
    let title: String
    let data: [DataPoint]
    let xValue: (DataPoint) -> String
    let yValue: (DataPoint) -> Int
    let formatYValue: (Int) -> String
    let detailText: (DataPoint) -> String
    let barColor: (DataPoint, Bool) -> Color
    let height: CGFloat
    let showTimeRangePicker: Bool
    let timeRanges: [TimeRange]

    @State private var selectedPoint: DataPoint?
    @Binding var selectedRange: TimeRange?

    init(
        title: String,
        data: [DataPoint],
        xValue: @escaping (DataPoint) -> String,
        yValue: @escaping (DataPoint) -> Int,
        formatYValue: @escaping (Int) -> String = { "\($0)" },
        detailText: @escaping (DataPoint) -> String,
        barColor: @escaping (DataPoint, Bool) -> Color = { _, selected in selected ? .accentColor : .blue.opacity(0.6) },
        height: CGFloat = 140,
        showTimeRangePicker: Bool = false,
        timeRanges: [TimeRange] = [],
        selectedRange: Binding<TimeRange?> = .constant(nil)
    ) {
        self.title = title
        self.data = data
        self.xValue = xValue
        self.yValue = yValue
        self.formatYValue = formatYValue
        self.detailText = detailText
        self.barColor = barColor
        self.height = height
        self.showTimeRangePicker = showTimeRangePicker
        self.timeRanges = timeRanges
        self._selectedRange = selectedRange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let point = selectedPoint {
                    Text(detailText(point))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                } else if showTimeRangePicker {
                    timeRangePicker
                }
            }

            Chart(data) { point in
                BarMark(
                    x: .value("X", xValue(point)),
                    y: .value("Y", yValue(point))
                )
                .foregroundStyle(barColor(point, selectedPoint?.id == point.id))
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel()
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(formatYValue(v))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geo[proxy.plotFrame!].origin.x
                                    if let xStr: String = proxy.value(atX: x) {
                                        selectedPoint = data.first { xValue($0) == xStr }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.3)) { selectedPoint = nil }
                                }
                        )
                }
            }
            .frame(height: height)
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }

    private var timeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(timeRanges, id: \.id) { range in
                Button(action: {
                    withAnimation {
                        selectedRange = range
                        selectedPoint = nil
                    }
                }) {
                    Text(range.label)
                        .font(.system(size: 11, weight: selectedRange?.id == range.id ? .semibold : .regular))
                        .foregroundColor(selectedRange?.id == range.id ? .white : .secondary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedRange?.id == range.id ? Color.accentColor.opacity(0.3) : Color.clear)
                        .cornerRadius(6)
                }
            }
        }
    }
}

struct TimeRange: Identifiable {
    let id: String
    let label: String
    let days: Int?

    init(label: String, days: Int?) {
        self.id = label
        self.label = label
        self.days = days
    }
}
