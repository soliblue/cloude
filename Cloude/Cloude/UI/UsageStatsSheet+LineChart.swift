import SwiftUI
import Charts

struct InteractiveLineChart<DataPoint: Identifiable>: View {
    let title: String
    let data: [DataPoint]
    let xValue: (DataPoint) -> String
    let yValue: (DataPoint) -> Int
    let formatYValue: (Int) -> String
    let detailText: (DataPoint) -> String
    let lineColor: (DataPoint, Bool) -> Color
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
        lineColor: @escaping (DataPoint, Bool) -> Color = { _, selected in selected ? .accentColor : .blue.opacity(DS.Opacity.l) },
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
        self.lineColor = lineColor
        self.height = height
        self.showTimeRangePicker = showTimeRangePicker
        self.timeRanges = timeRanges
        self._selectedRange = selectedRange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Text(title)
                    .font(.system(size: DS.Text.m, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let point = selectedPoint {
                    Text(detailText(point))
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.secondary.opacity(DS.Opacity.l))
                } else if showTimeRangePicker {
                    timeRangePicker
                }
            }

            Chart(Array(data.enumerated()), id: \.element.id) { idx, point in
                LineMark(
                    x: .value("X", idx),
                    y: .value("Y", yValue(point))
                )
                .foregroundStyle(lineColor(point, false))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: DS.Stroke.l))

                PointMark(
                    x: .value("X", idx),
                    y: .value("Y", yValue(point))
                )
                .foregroundStyle(lineColor(point, selectedPoint?.id == point.id))
                .symbolSize(selectedPoint?.id == point.id ? 40 : 20)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let idx = value.as(Int.self), idx >= 0, idx < data.count {
                            Text(xValue(data[idx]))
                                .font(.system(size: DS.Text.s))
                                .foregroundStyle(.secondary.opacity(DS.Opacity.l))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(formatYValue(v))
                                .font(.system(size: DS.Text.s))
                                .foregroundStyle(.secondary.opacity(DS.Opacity.l))
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
                                    if let idx: Int = proxy.value(atX: x), idx >= 0, idx < data.count {
                                        selectedPoint = data[idx]
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: DS.Duration.m)) { selectedPoint = nil }
                                }
                        )
                }
            }
            .frame(height: height)
        }
        .padding(DS.Spacing.l)
        .background(.white.opacity(DS.Opacity.s))
        .cornerRadius(DS.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).strokeBorder(.white.opacity(DS.Opacity.s), lineWidth: DS.Stroke.s))
    }

    private var timeRangePicker: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(timeRanges, id: \.id) { range in
                Button(action: {
                    withAnimation {
                        selectedRange = range
                        selectedPoint = nil
                    }
                }) {
                    Text(range.label)
                        .font(.system(size: DS.Text.s, weight: selectedRange?.id == range.id ? .semibold : .regular))
                        .foregroundColor(selectedRange?.id == range.id ? .white : .secondary.opacity(DS.Opacity.l))
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(selectedRange?.id == range.id ? Color.accentColor.opacity(DS.Opacity.m) : Color.clear)
                        .cornerRadius(DS.Radius.s)
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
