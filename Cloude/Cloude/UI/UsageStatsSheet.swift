import SwiftUI
import Charts
import CloudeShared

struct UsageStatsSheet: View {
    let stats: UsageStats
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeRange: TimeRange?

    private let timeRanges = [
        TimeRange(label: "7d", days: 7),
        TimeRange(label: "14d", days: 14),
        TimeRange(label: "30d", days: 30),
        TimeRange(label: "All", days: nil)
    ]

    private var totalToolCalls: Int {
        stats.dailyActivity.reduce(0) { $0 + $1.toolCallCount }
    }

    private var daysActive: Int { stats.dailyActivity.count }

    private var memberSinceFormatted: String? {
        guard let dateStr = stats.firstSessionDate else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: dateStr) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }

    private var recentActivity: [DailyActivity] {
        if let days = selectedTimeRange?.days {
            return Array(stats.dailyActivity.suffix(days))
        }
        return Array(stats.dailyActivity.suffix(14))
    }

    private var sortedModels: [(name: String, tokens: ModelTokens)] {
        stats.modelUsage.sorted { $0.value.outputTokens > $1.value.outputTokens }
            .map { (name: modelDisplayName($0.key), tokens: $0.value) }
    }

    private var maxOutputTokens: Int { sortedModels.first?.tokens.outputTokens ?? 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroRow
                    activityChart
                    modelsSection
                    peakHoursSection
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.oceanBackground)
    }

    private var heroRow: some View {
        HStack(spacing: 0) {
            StatPill(value: formatNumber(stats.totalMessages), label: "msgs", color: .blue)
            Divider().frame(height: 28).padding(.horizontal, 4)
            StatPill(value: formatNumber(stats.totalSessions), label: "sessions", color: .purple)
            Divider().frame(height: 28).padding(.horizontal, 4)
            StatPill(value: formatNumber(totalToolCalls), label: "tools", color: .orange)
            Divider().frame(height: 28).padding(.horizontal, 4)
            StatPill(value: "\(daysActive)", label: "days", color: .green)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }

    private var activityChart: some View {
        InteractiveBarChart(
            title: "Activity",
            data: recentActivity,
            xValue: { chartDateLabel($0.date) },
            yValue: { $0.messageCount },
            formatYValue: formatNumber,
            detailText: { "\(chartDateLabel($0.date)) — \(formatNumber($0.messageCount)) msgs, \($0.sessionCount) sessions" },
            barColor: { _, selected in selected ? .accentColor : .blue.opacity(0.6) },
            showTimeRangePicker: true,
            timeRanges: timeRanges,
            selectedRange: $selectedTimeRange
        )
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Models")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(sortedModels, id: \.name) { model in
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 64, alignment: .leading)

                    GeometryReader { geo in
                        let fraction = CGFloat(model.tokens.outputTokens) / CGFloat(max(maxOutputTokens, 1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(modelColor(model.name))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                    .frame(height: 14)

                    Text(formatNumber(model.tokens.outputTokens))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }

    private var peakHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Peak Hours")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            let maxCount = stats.hourCounts.values.max() ?? 1

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = stats.hourCounts["\(hour)"] ?? 0
                    let height = CGFloat(count) / CGFloat(max(maxCount, 1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(peakColor(hour))
                        .frame(height: max(2, height * 44))
                }
            }
            .frame(height: 48)

            HStack {
                Text("12a").frame(maxWidth: .infinity, alignment: .leading)
                Text("6a").frame(maxWidth: .infinity)
                Text("12p").frame(maxWidth: .infinity)
                Text("6p").frame(maxWidth: .infinity)
                Text("12a").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }

    private var footerSection: some View {
        HStack(spacing: 16) {
            if let since = memberSinceFormatted {
                Label(since, systemImage: "person.crop.circle")
            }
            if let longest = stats.longestSession {
                Label("\(longest.messageCount) msg record", systemImage: "trophy")
            }
            let peakHour = stats.hourCounts.max(by: { $0.value < $1.value })
            if let peak = peakHour, let h = Int(peak.key) {
                Label(formatHour(h), systemImage: "clock")
            }
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary.opacity(0.6))
        .padding(.top, 2)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func shortDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3, let day = Int(parts[2]) else { return dateStr }
        return "\(day)"
    }

    private func chartDateLabel(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return dateStr }
        let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthName = month > 0 && month <= 12 ? months[month] : "\(month)"

        let activity = recentActivity
        let idx = activity.firstIndex { $0.date == dateStr }
        let isFirst = idx == activity.startIndex
        let prevMonth: Bool = {
            guard let i = idx, i > activity.startIndex else { return false }
            let prev = activity[activity.index(before: i)].date.split(separator: "-")
            return prev.count == 3 && prev[1] != parts[1]
        }()

        if isFirst || prevMonth {
            return "\(monthName) \(day)"
        }
        return "\(day)"
    }

    private func modelDisplayName(_ name: String) -> String {
        if name.contains("opus-4-6") { return "Opus 4.6" }
        if name.contains("opus-4-5") { return "Opus 4.5" }
        if name.contains("sonnet") { return "Sonnet" }
        if name.contains("haiku") { return "Haiku" }
        return name.components(separatedBy: "-").prefix(2).joined(separator: " ").capitalized
    }

    private func modelColor(_ name: String) -> LinearGradient {
        let colors: [Color]
        switch name {
        case "Opus 4.5": colors = [.purple, .purple.opacity(0.7)]
        case "Opus 4.6": colors = [.blue, .cyan]
        case "Sonnet":   colors = [.orange, .yellow]
        case "Haiku":    colors = [.green, .mint]
        default:         colors = [.gray, .gray.opacity(0.7)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private func peakColor(_ hour: Int) -> Color {
        let count = stats.hourCounts["\(hour)"] ?? 0
        let maxCount = stats.hourCounts.values.max() ?? 1
        let intensity = Double(count) / Double(max(maxCount, 1))
        return Color.blue.opacity(0.3 + intensity * 0.7)
    }

    private func formatHour(_ h: Int) -> String {
        if h == 0 { return "12 AM" }
        if h < 12 { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}
