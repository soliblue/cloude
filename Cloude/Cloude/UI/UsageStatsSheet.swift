import SwiftUI
import Charts
import CloudeShared

struct UsageStatsSheet: View {
    let stats: UsageStats
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: DailyActivity?

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
        Array(stats.dailyActivity.suffix(14))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let day = selectedDay {
                    Text("\(shortDate(day.date)) — \(formatNumber(day.messageCount)) msgs, \(day.sessionCount) sessions")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Chart(recentActivity, id: \.date) { day in
                BarMark(
                    x: .value("Date", shortDate(day.date)),
                    y: .value("Messages", day.messageCount)
                )
                .foregroundStyle(selectedDay?.date == day.date ? Color.accentColor : Color.blue.opacity(0.6))
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
                            Text(formatNumber(v))
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
                                    if let dateStr: String = proxy.value(atX: x) {
                                        selectedDay = recentActivity.first { shortDate($0.date) == dateStr }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.3)) { selectedDay = nil }
                                }
                        )
                }
            }
            .frame(height: 140)
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
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
        guard parts.count == 3 else { return dateStr }
        return "\(parts[1])/\(parts[2])"
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
