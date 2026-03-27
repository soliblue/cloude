import SwiftUI
import Charts
import CloudeShared

extension UsageStatsSheet {
    var chartModes: [(icon: String, label: String, color: Color)] {
        [
            ("message.fill", "Messages", .blue),
            ("square.stack.fill", "Sessions", .purple),
            ("wrench.fill", "Tool Calls", .orange)
        ]
    }

    var activityChart: some View {
        VStack(spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(0..<chartModes.count, id: \.self) { i in
                    Button(action: { withAnimation(.quickTransition) { chartPage = i } }) {
                        Image(systemName: chartModes[i].icon)
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(chartPage == i ? chartModes[i].color : .secondary.opacity(DS.Opacity.m))
                            .frame(width: DS.Spacing.xxl, height: DS.Size.m)
                            .background(chartPage == i ? chartModes[i].color.opacity(DS.Opacity.s) : .clear)
                            .cornerRadius(DS.Radius.s)
                    }
                }
            }

            Group {
                switch chartPage {
                case 0:
                    InteractiveLineChart(
                        title: "Messages",
                        data: recentActivity,
                        xValue: { chartDateLabel($0.date) },
                        yValue: { $0.messageCount },
                        formatYValue: formatNumber,
                        detailText: { "\(chartDateLabel($0.date)) — \(formatNumber($0.messageCount)) msgs" },
                        lineColor: { _, selected in selected ? .accentColor : .blue.opacity(DS.Opacity.l) },
                        showTimeRangePicker: true,
                        timeRanges: timeRanges,
                        selectedRange: $selectedTimeRange
                    )
                case 1:
                    InteractiveLineChart(
                        title: "Sessions",
                        data: recentActivity,
                        xValue: { chartDateLabel($0.date) },
                        yValue: { $0.sessionCount },
                        formatYValue: formatNumber,
                        detailText: { "\(chartDateLabel($0.date)) — \($0.sessionCount) sessions" },
                        lineColor: { _, selected in selected ? .accentColor : .purple.opacity(DS.Opacity.l) },
                        showTimeRangePicker: true,
                        timeRanges: timeRanges,
                        selectedRange: $selectedTimeRange
                    )
                default:
                    InteractiveLineChart(
                        title: "Tool Calls",
                        data: recentActivity,
                        xValue: { chartDateLabel($0.date) },
                        yValue: { $0.toolCallCount },
                        formatYValue: formatNumber,
                        detailText: { "\(chartDateLabel($0.date)) — \(formatNumber($0.toolCallCount)) tools" },
                        lineColor: { _, selected in selected ? .accentColor : .orange.opacity(DS.Opacity.l) },
                        showTimeRangePicker: true,
                        timeRanges: timeRanges,
                        selectedRange: $selectedTimeRange
                    )
                }
            }
        }
    }

    var modelsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("Models")
                .font(.system(size: DS.Text.m, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(sortedModels, id: \.name) { model in
                HStack(spacing: DS.Spacing.s) {
                    Text(model.name)
                        .font(.system(size: DS.Text.m, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: DS.Size.xl, alignment: .leading)

                    GeometryReader { geo in
                        let fraction = CGFloat(model.tokens.outputTokens) / CGFloat(max(maxOutputTokens, 1))
                        RoundedRectangle(cornerRadius: DS.Radius.s)
                            .fill(modelColor(model.name))
                            .frame(width: max(DS.Spacing.xs, geo.size.width * fraction))
                    }
                    .frame(height: DS.Text.s)

                    Text(formatNumber(model.tokens.outputTokens))
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: DS.Size.l, alignment: .trailing)
                }
            }
        }
        .padding(DS.Spacing.l)
        .background(.white.opacity(DS.Opacity.s))
        .cornerRadius(DS.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).strokeBorder(.white.opacity(DS.Opacity.s), lineWidth: DS.Stroke.s))
    }

    var peakHoursSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Peak Hours")
                .font(.system(size: DS.Text.m, weight: .semibold))
                .foregroundColor(.secondary)

            let maxCount = stats.hourCounts.values.max() ?? 1

            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = stats.hourCounts["\(hour)"] ?? 0
                    let height = CGFloat(count) / CGFloat(max(maxCount, 1))
                    RoundedRectangle(cornerRadius: DS.Radius.s)
                        .fill(peakColor(hour))
                        .frame(height: max(DS.Spacing.xs, height * DS.Size.xl))
                }
            }
            .frame(height: DS.Size.xl)

            HStack {
                Text("12a").frame(maxWidth: .infinity, alignment: .leading)
                Text("6a").frame(maxWidth: .infinity)
                Text("12p").frame(maxWidth: .infinity)
                Text("6p").frame(maxWidth: .infinity)
                Text("12a").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: DS.Text.s))
            .foregroundColor(.secondary.opacity(DS.Opacity.m))
        }
        .padding(DS.Spacing.l)
        .background(.white.opacity(DS.Opacity.s))
        .cornerRadius(DS.Radius.m)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).strokeBorder(.white.opacity(DS.Opacity.s), lineWidth: DS.Stroke.s))
    }
}
